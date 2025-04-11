// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice The L1 Outbox to exit a arbitrum bridge transaction on Mainnet
interface IArbitrumOutbox {
    /// @notice Executes a transaction by providing a generated proof
    /// @param proof The proof to exit with
    /// @param index The index of the transaction in the block
    /// @param l2sender The executor of the L2 transaction
    /// @param to The L1 gateway address that the L2 transaction was sent to
    /// @param l2block The L2 block where the transaction took place
    /// @param l1block The L1 block where the transaction took place
    /// @param l2timestamp The L2 timestamp when the transaction took place
    /// @param value The value sent with the transaction
    /// @param data Any extra data sent with the transaction
    function executeTransaction(
        bytes32[] calldata proof,
        uint256 index,
        address l2sender,
        address to,
        uint256 l2block,
        uint256 l1block,
        uint256 l2timestamp,
        uint256 value,
        bytes calldata data
    ) external;
}
