// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice L2 Gateway to initiate bridge
interface IArbitrumGateway {
    /// @notice Executes a burn transaction to initiate a bridge
    /// @param tokenAddress The L11 address of the token to burn
    /// @param recipient Receiver of the bridged tokens
    /// @param amount The amount of tokens to bridge
    /// @param data Any extra data to include in the burn transaction
    function outboundTransfer(
        address tokenAddress,
        address recipient,
        uint256 amount,
        bytes calldata data
    ) external;
}
