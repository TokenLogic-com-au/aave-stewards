// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20PredicateBurnOnly {
    /// @dev Function needs to be called in order to confirm a withdrawal
    /// @param data The generated proof to confirm a withdrawal transaction
    function startExitWithBurntTokens(bytes calldata data) external;
}

interface IWithdrawManager {
    /// @dev Last step in exiting a token bridge
    /// @param _token Address of the token being withdrawn
    function processExits(address _token) external;

    /// @dev Last step in exiting a multi-token bridge
    /// @param _tokens Array of token addresses being withdrawn
    function processExitsBatch(address[] calldata _tokens) external;
}
