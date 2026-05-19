// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ICollector} from "aave-address-book/AaveV3.sol";
import {AaveV3Ethereum} from "aave-address-book/AaveV3Ethereum.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableWithGuardian} from "solidity-utils/contracts/access-control/OwnableWithGuardian.sol";
import {RescuableBase, IRescuableBase} from "solidity-utils/contracts/utils/RescuableBase.sol";

import {IOFTBridgeSteward} from "./interfaces/IOFTBridgeSteward.sol";
import {IOFT, SendParam, MessagingFee, OFTReceipt} from "./interfaces/IOFT.sol";
import {OFTConstants} from "./OFTConstants.sol";

/// @title OFTBridgeSteward
/// @author @stevyhacker, jubeira (TokenLogic)
/// @notice Helper contract to bridge USDT using OFT V2 (LayerZero OFT)
contract OFTBridgeSteward is OwnableWithGuardian, RescuableBase, IOFTBridgeSteward {
  using SafeERC20 for IERC20;

  /// @inheritdoc IOFTBridgeSteward
  uint32 public constant DESTINATION_EID = OFTConstants.ETHEREUM_EID;

  /// @inheritdoc IOFTBridgeSteward
  address public constant MAINNET_COLLECTOR = address(AaveV3Ethereum.COLLECTOR);

  /// @inheritdoc IOFTBridgeSteward
  address public immutable OFT_USDT;

  /// @inheritdoc IOFTBridgeSteward
  /// @dev Assumes `IERC20(USDT).decimals() == IOFT(OFT_USDT).sharedDecimals()`. If they ever differ, OFT
  ///      will truncate the bridged amount to shared decimals on send and the dust will remain on the
  ///      steward (recoverable via `rescueToken`). For USDT/USDT0 this is 6 == 6.
  address public immutable USDT;

  /// @inheritdoc IOFTBridgeSteward
  address public immutable COLLECTOR;

  /// @param oftUsdt The OFT address for USDT on this chain
  /// @param initialOwner The initial owner of the contract
  /// @param initialGuardian The initial guardian of the contract
  /// @param collector The local Aave Collector that holds the USDT to bridge and receives rescues / LayerZero refunds
  constructor(address oftUsdt, address initialOwner, address initialGuardian, address collector)
    OwnableWithGuardian(initialOwner, initialGuardian)
  {
    if (oftUsdt == address(0)) revert InvalidZeroAddress();
    if (initialOwner == address(0)) revert InvalidZeroAddress();
    if (initialGuardian == address(0)) revert InvalidZeroAddress();
    if (collector == address(0)) revert InvalidZeroAddress();

    OFT_USDT = oftUsdt;
    USDT = IOFT(OFT_USDT).token();
    COLLECTOR = collector;
  }

  /// @dev Default receive function enabling the contract to accept native tokens for gas fees
  receive() external payable {}

  /// @inheritdoc IOFTBridgeSteward
  function bridge(uint256 amount, uint256 minAmountLD, uint256 maxFee) external payable onlyOwnerOrGuardian {
    if (amount == 0) revert InvalidZeroAmount();
    if (minAmountLD == 0) revert InvalidZeroAmount();

    (SendParam memory sendParam, MessagingFee memory messagingFee) =
      _buildSendParamsAndMessagingFee(amount, minAmountLD);
    uint256 nativeFee = messagingFee.nativeFee;

    if (nativeFee > maxFee) revert MaxFeeExceeded(nativeFee, maxFee);
    if (address(this).balance < nativeFee) revert InsufficientBalance(address(this).balance, nativeFee);

    // Pull pre-approved USDT funds from collector.
    ICollector(COLLECTOR).transfer(IERC20(USDT), address(this), amount);

    // Approve OFT to pull USDT and bridge funds to destination chain.
    // Reset approvals to 0 to ensure no dangling approval persists afterwards for any reason.
    IERC20(USDT).forceApprove(OFT_USDT, amount);
    IOFT(OFT_USDT).send{value: nativeFee}(sendParam, messagingFee, COLLECTOR);
    IERC20(USDT).forceApprove(OFT_USDT, 0);

    emit Bridge(USDT, DESTINATION_EID, MAINNET_COLLECTOR, amount, minAmountLD);
  }

  /// @inheritdoc IOFTBridgeSteward
  function rescueToken(address token) external onlyOwnerOrGuardian {
    _emergencyTokenTransfer(token, COLLECTOR, type(uint256).max);
  }

  /// @inheritdoc IOFTBridgeSteward
  function rescueEth() external onlyOwnerOrGuardian {
    _emergencyEtherTransfer(COLLECTOR, address(this).balance);
  }

  /// @inheritdoc IOFTBridgeSteward
  function quoteSendFee(uint256 amount, uint256 minAmountLD) external view returns (uint256) {
    (, MessagingFee memory messagingFee) = _buildSendParamsAndMessagingFee(amount, minAmountLD);
    return messagingFee.nativeFee;
  }

  /// @inheritdoc IOFTBridgeSteward
  function quoteAmountReceived(uint256 amount) external view returns (uint256) {
    SendParam memory sendParam = _buildSendParams(amount, 0);
    (,, OFTReceipt memory receipt) = IOFT(OFT_USDT).quoteOFT(sendParam);
    return receipt.amountReceivedLD;
  }

  /// @inheritdoc IRescuableBase
  function maxRescue(address token) public view override(RescuableBase) returns (uint256) {
    return IERC20(token).balanceOf(address(this));
  }

  /// @notice Helper function to build SendParam for a given amount and minAmountLD
  function _buildSendParams(uint256 amount, uint256 minAmountLD) internal pure returns (SendParam memory) {
    return SendParam({
      dstEid: DESTINATION_EID,
      to: bytes32(uint256(uint160(MAINNET_COLLECTOR))),
      amountLD: amount,
      minAmountLD: minAmountLD,
      extraOptions: new bytes(0),
      composeMsg: new bytes(0),
      oftCmd: new bytes(0)
    });
  }

  /// @notice Helper function to build SendParam and MessagingFee for a given amount and minAmountLD
  function _buildSendParamsAndMessagingFee(uint256 amount, uint256 minAmountLD)
    internal
    view
    returns (SendParam memory, MessagingFee memory)
  {
    SendParam memory sendParam = _buildSendParams(amount, minAmountLD);
    MessagingFee memory messagingFee = IOFT(OFT_USDT).quoteSend(sendParam, false);

    return (sendParam, messagingFee);
  }
}
