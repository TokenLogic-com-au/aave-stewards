// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ICollector} from "aave-helpers/src/CollectorUtils.sol";

interface IBridgeSteward {
    /// @dev Calling function is not available on specific chain
    error InvalidChain();

    /// @dev Emit when bridge token
    /// @param fromChainId The chain id of from network
    /// @param toChainId The chain id of to network
    /// @param token The address of bridged token
    /// @param amount The amount of bridged token
    event TokenBridged(
        uint256 indexed fromChainId,
        uint256 indexed toChainId,
        address indexed token,
        uint256 amount
    );

    /// @notice Returns instance of Aave V3 Collector
    function COLLECTOR() external view returns (ICollector);

    /// @notice Withdraw assets from Polygon to Mainnet
    /// @param token The address of ERC20 token to withdraw
    /// @param amount The amount of token to withdraw
    function withdrawOnPolygon(address token, uint256 amount) external;

    /// @notice Withdraw assets from Arbitrum to Mainnet
    /// @param tokenOnL2 The address of ERC20 token on Arbitrum
    /// @param tokenOnL1 The address of ERC20 token on Mainnet
    /// @param gateway The address of token gateway
    /// @param amount The amount of token to withdraw
    function withdrawOnArbitrum(
        address tokenOnL2,
        address tokenOnL1,
        address gateway,
        uint256 amount
    ) external;

    /// @notice Withdraw assets from Optimism to Mainnet
    /// @param tokenOnL2 The address of ERC20 token on Optimism
    /// @param tokenOnL1 The address of ERC20 token on Mainnet
    /// @param amount The amount of token to withdraw
    function withdrawOnOptimism(
        address tokenOnL2,
        address tokenOnL1,
        uint256 amount
    ) external;

    /// @notice Rescues the specified token back to the Collector
    /// @param token The address of the ERC20 token to rescue
    function rescueToken(address token) external;

    /// @notice Rescues ETH from the contract back to the Collector
    function rescueEth() external;
}
