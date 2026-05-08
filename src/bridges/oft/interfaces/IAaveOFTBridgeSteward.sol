// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAaveOFTBridgeSteward {
  /// @dev Thrown when the contract balance is not enough to pay the native fee
  /// @param contractBalance The current balance of the contract
  /// @param nativeFee The required native fee for the bridge
  error InsufficientBalance(uint256 contractBalance, uint256 nativeFee);

  /// @dev Thrown when bridge amount or min amount to receive is zero
  error InvalidZeroAmount();

  /// @dev Thrown when a zero address is provided
  error InvalidZeroAddress();

  /// @dev Thrown when the max fee is exceeded when bridging
  /// @param requiredFee The required native fee for the bridge
  /// @param maxFee The maximum fee allowed as specified in the bridge call
  error MaxFeeExceeded(uint256 requiredFee, uint256 maxFee);

  /// @notice Emitted when USDT is bridged to a destination chain
  /// @param token The token address being bridged
  /// @param dstEid The destination LayerZero endpoint ID
  /// @param receiver The receiver address on destination
  /// @param amount The amount bridged
  /// @param minAmountReceived The minimum expected amount on destination
  event Bridge(
    address indexed token, uint32 indexed dstEid, address indexed receiver, uint256 amount, uint256 minAmountReceived
  );

  /// @notice Bridges USDT to a destination chain using OFT
  /// @dev Only callable by owner or guardian. Requires contract to hold at least the native fee for the bridge,
  ///      either paid for in this call or beforehand.
  ///      The bridged USDT will be pulled from the Collector, so the Collector must have approved this contract to
  ///      spend the specified amount of USDT.
  /// @param amount The amount of USDT to bridge
  /// @param minAmountLD The minimum amount to receive on destination (slippage protection)
  /// @param maxFee The maximum native fee in ETH wei allowed for the bridge
  function bridge(uint256 amount, uint256 minAmountLD, uint256 maxFee) external payable;

  /// @notice Rescues the specified token back to the Collector
  /// @param token The address of the ERC20 token to rescue
  function rescueToken(address token) external;

  /// @notice Rescues ETH from the contract back to the Collector
  function rescueEth() external;

  /// @notice Returns Mainnet EID (LayerZero Endpoint ID) for bridging
  function DESTINATION_EID() external view returns (uint32);

  /// @notice Returns the OFT address for USDT on the deployed chain
  function OFT_USDT() external view returns (address);

  /// @notice Returns the USDT token address on the deployed chain
  function USDT() external view returns (address);

  /// @notice Returns the Aave Collector address
  function COLLECTOR() external view returns (address);

  /// @notice Returns the receiver address for bridged tokens on the destination chain (Mainnet Collector)
  function RECEIVER() external view returns (address);

  /// @notice Quotes the native fee required to bridge USDT
  /// @param amount The amount of USDT to bridge
  /// @param minAmountLD The minimum amount to receive on destination
  /// @return nativeFee The native token fee required for bridging
  function quoteSendFee(uint256 amount, uint256 minAmountLD) external view returns (uint256);

  /// @notice Quotes the amount of USDT expected to be received on the destination chain
  /// @param amount The amount of USDT to bridge
  /// @return amountReceivedLD The amount of USDT expected to be received on the destination chain
  function quoteAmountReceived(uint256 amount) external view returns (uint256);
}
