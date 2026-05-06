// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ICollector} from "aave-address-book/AaveV3.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableWithGuardian} from "solidity-utils/contracts/access-control/OwnableWithGuardian.sol";
import {RescuableBase} from "solidity-utils/contracts/utils/RescuableBase.sol";

import {ICctpBridgeSteward} from "./interfaces/ICctpBridgeSteward.sol";
import {IMessageTransmitterV2} from "./interfaces/IMessageTransmitterV2.sol";
import {ITokenMessengerV2} from "./interfaces/ITokenMessengerV2.sol";
import {CctpConstants} from "./CctpConstants.sol";

/// @title CctpBridgeSteward
/// @author stevyhacker, jubeira (TokenLogic)
/// @notice Helper contract to bridge USDC using Circle's CCTP V2
contract CctpBridgeSteward is OwnableWithGuardian, RescuableBase, ICctpBridgeSteward {
  using SafeERC20 for IERC20;

  /// @inheritdoc ICctpBridgeSteward
  uint32 public constant DESTINATION_DOMAIN = CctpConstants.ETHEREUM_DOMAIN;

  /// @inheritdoc ICctpBridgeSteward
  address public immutable TOKEN_MESSENGER;

  /// @inheritdoc ICctpBridgeSteward
  address public immutable USDC;

  /// @inheritdoc ICctpBridgeSteward
  address public immutable COLLECTOR;

  /// @inheritdoc ICctpBridgeSteward
  address public immutable RECEIVER;

  /// @inheritdoc ICctpBridgeSteward
  /// @dev Captured at deploy time from the (upgradeable) TokenMessengerV2 / MessageTransmitterV2.
  ///      A redeploy is required if Circle migrates these contracts and the local domain changes.
  uint32 public immutable LOCAL_DOMAIN;

  /// @param tokenMessenger The TokenMessengerV2 address on this chain
  /// @param usdc The USDC token address on this chain
  /// @param owner The owner of the contract upon deployment
  /// @param guardian The initial guardian of the contract upon deployment
  /// @param collector The address of the source collector on this chain
  /// @param receiver The address of the destination receiver (Mainnet collector) for bridge transfers
  constructor(
    address tokenMessenger,
    address usdc,
    address owner,
    address guardian,
    address collector,
    address receiver
  ) OwnableWithGuardian(owner, guardian) {
    if (tokenMessenger == address(0)) revert InvalidZeroAddress();
    if (usdc == address(0)) revert InvalidZeroAddress();
    if (guardian == address(0)) revert InvalidZeroAddress();
    if (collector == address(0)) revert InvalidZeroAddress();
    if (receiver == address(0)) revert InvalidZeroAddress();

    TOKEN_MESSENGER = tokenMessenger;
    USDC = usdc;
    COLLECTOR = collector;
    RECEIVER = receiver;

    address localMessageTransmitter = ITokenMessengerV2(tokenMessenger).localMessageTransmitter();
    LOCAL_DOMAIN = IMessageTransmitterV2(localMessageTransmitter).localDomain();
    if (LOCAL_DOMAIN == DESTINATION_DOMAIN) revert InvalidLocalDomain();
  }

  /// @dev No use case to receive ETH; prevent accidental transfers.
  receive() external payable {
    if (msg.value > 0) revert CannotReceiveEther();
  }

  /// @inheritdoc ICctpBridgeSteward
  function bridge(uint256 amount, uint256 maxFee, TransferSpeed speed) external onlyOwnerOrGuardian {
    if (amount == 0) revert InvalidZeroAmount();
    if (maxFee >= amount) revert InvalidMaxFee(maxFee, amount);

    uint32 finalityThreshold;
    if (speed == TransferSpeed.Fast) {
      finalityThreshold = CctpConstants.FAST_FINALITY_THRESHOLD;
    } else if (speed == TransferSpeed.Standard) {
      finalityThreshold = CctpConstants.STANDARD_FINALITY_THRESHOLD;
    } else {
      revert InvalidTransferSpeed();
    }

    ICollector(COLLECTOR).transfer(IERC20(USDC), address(this), amount);
    IERC20(USDC).forceApprove(TOKEN_MESSENGER, amount);

    ITokenMessengerV2(TOKEN_MESSENGER)
      .depositForBurn(
        amount, DESTINATION_DOMAIN, bytes32(uint256(uint160(RECEIVER))), USDC, bytes32(0), maxFee, finalityThreshold
      );

    // Clear the allowance to prevent any potential issues down the line.
    IERC20(USDC).forceApprove(TOKEN_MESSENGER, 0);

    emit Bridge(USDC, DESTINATION_DOMAIN, RECEIVER, amount, speed);
  }

  /// @inheritdoc ICctpBridgeSteward
  function rescueToken(address token) external onlyOwnerOrGuardian {
    _emergencyTokenTransfer(token, COLLECTOR, type(uint256).max);
  }

  /// @inheritdoc ICctpBridgeSteward
  function rescueEth() external onlyOwnerOrGuardian {
    _emergencyEtherTransfer(COLLECTOR, address(this).balance);
  }

  /// @inheritdoc RescuableBase
  function maxRescue(address token) public view override(RescuableBase) returns (uint256) {
    return IERC20(token).balanceOf(address(this));
  }
}
