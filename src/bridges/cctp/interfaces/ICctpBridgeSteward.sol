// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title ICctpBridgeSteward
/// @author TokenLogic
/// @notice Interface for the Aave CCTP V2 Bridge adapter for USDC cross-chain transfers
interface ICctpBridgeSteward {
  /// @notice Transfer speed options for CCTP V2
  enum TransferSpeed {
    Fast, // Finality threshold 1000 - faster but with fee
    Standard // Finality threshold 2000 - slower but potentially lower/no fee
  }

  /// @notice Emitted when a bridge transfer is initiated
  /// @param token The address of the bridged token (USDC)
  /// @param destinationDomain The CCTP domain of the destination chain
  /// @param receiver The recipient address on the destination chain (bytes32 to support non-EVM)
  /// @param amount The amount of tokens bridged
  /// @param speed The transfer speed used (Fast or Standard)
  event Bridge(
    address indexed token,
    uint32 indexed destinationDomain,
    address indexed receiver,
    uint256 amount,
    TransferSpeed speed
  );

  /// @dev `receive` callback was called with non-zero ETH value, which is not supported
  error CannotReceiveEther();

  /// @dev Contract was deployed to Ethereum mainnet, which does not require a bridge
  error InvalidLocalDomain();

  /// @dev maxFee is greater than or equal to the amount being bridged, which is invalid
  error InvalidMaxFee(uint256 maxFee, uint256 amount);

  /// @dev TransferSpeed value is not a recognised member of the enum
  error InvalidTransferSpeed();

  /// @dev Constructor parameter is zero address
  error InvalidZeroAddress();

  /// @dev Amount provided is zero
  error InvalidZeroAmount();

  /// @notice Bridges USDC to a destination chain using CCTP V2
  /// @param amount The amount of USDC to bridge, denominated in USDC with 6 decimals, 1 USDC = 1_000_000
  /// @param maxFee Maximum fee willing to pay for a Fast Transfer, denominated in USDC with 6 decimals, 1 USDC = 1_000_000
  /// @param speed Transfer speed (Fast or Standard)
  function bridge(uint256 amount, uint256 maxFee, TransferSpeed speed) external;

  /// @notice Rescues an ERC20 token balance to the source collector
  /// @param token The token address to rescue
  function rescueToken(address token) external;

  /// @notice Rescues native token balance to the source collector
  function rescueEth() external;

  /// @notice Returns the CCTP domain identifier for the destination chain (Ethereum Mainnet)
  /// @return The domain ID for the destination chain
  function DESTINATION_DOMAIN() external view returns (uint32);

  /// @notice Returns the TokenMessengerV2 contract address
  /// @return Address of the CCTP V2 TokenMessenger
  function TOKEN_MESSENGER() external view returns (address);

  /// @notice Returns the USDC token address on this chain
  /// @return Address of the USDC token
  function USDC() external view returns (address);

  /// @notice Returns the source collector address on this chain
  /// @return Address of the source collector
  function COLLECTOR() external view returns (address);

  /// @notice Returns the destination receiver address (Mainnet collector) for bridge transfers
  /// @return Address of the destination receiver (Mainnet collector)
  function RECEIVER() external view returns (address);

  /// @notice Returns the local CCTP domain identifier
  /// @dev Captured at deploy time from the (upgradeable) TokenMessengerV2 / MessageTransmitterV2.
  ///      A redeploy is required if Circle migrates these contracts and the local domain changes.
  /// @return The domain ID for this chain
  function LOCAL_DOMAIN() external view returns (uint32);
}
