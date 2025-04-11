// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ICollector} from "aave-helpers/src/CollectorUtils.sol";

interface IBridgeSteward {
    /// @dev Calling function is not available on specific chain
    error InvalidChain();

    /// @dev Emits when bridge token
    /// @param fromChainId The chain id of from network
    /// @param token The address of bridged token
    /// @param amount The amount of bridged token
    event Bridge(
        uint256 indexed fromChainId,
        address indexed token,
        uint256 amount
    );

    /// @dev Emits when exit bridging on mainnet
    /// @param fromChainId Chain id that bridge initialized
    /// @param externalData External data of bridge like burnProof
    event Exit(uint256 indexed fromChainId, bytes externalData);

    /// @dev Emits when withdraw token to collector on mainnet
    /// @param token The address of token
    /// @param amount The amount of token
    event WithdrawToCollector(address indexed token, uint256 amount);

    /// @notice Returns the address of the Mainnet contract to exit the burn from for Polygon bridge
    function POL_ROOT_CHAIN_MANAGER() external view returns (address);

    /// @dev The mainnet address of the Predicate contract to confirm withdrawal
    function POL_ERC20_PREDICATE_BURN() external view returns (address);

    /// @dev The mainnet address of the withdrawal contract to exit the bridge
    function POL_WITHDRAW_MANAGER() external view returns (address);

    /// @dev The mainnet address of the MATIC token
    function POL_MATIC_MAINNET() external view returns (address);

    /// @dev The polygon address of the MATIC token
    function POL_MATIC_POLYGON() external view returns (address);

    /// @notice Returns the address of the Mainnet contract to exit the bridge from Arbitrum bridge
    function ARB_OUTBOX() external view returns (address);

    /// @notice Returns the Optimism Standard Bridge Address
    function OPT_STANDARD_BRIDGE() external returns (address);

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

    /// @notice Finalize ERC20 bridge from Polygon
    /// @param burnProof Burn proof generated via API.
    function exitFromPolygon(bytes calldata burnProof) external;

    /// @notice Start finalizing POL bridge from Polygon
    /// @param burnProof Burn proof generated via API.
    function startExitPolBridge(bytes calldata burnProof) external;

    /// @notice Completes the finalizing process of POL bridge from Polygon
    function exitPolBridge() external;

    /// @notice This function completes the withdrawal process from Arbitrum to Mainnet.
    /// Burn proof is generated via API. Please see README.md
    /// @param proof[] Burn proof generated via API.
    /// @param index The index of the burn transaction.
    /// @param l2sender The address sending the transaction from the L2
    /// @param destinationGateway The L1 gateway address receiving the bridged funds
    /// @param l2block The block number of the transaction on the L2
    /// @param l1block The block number of the transaction on the L1
    /// @param l2timestamp The timestamp of the transaction on the L2
    /// @param value The value being bridged from the L2
    /// @param data Data being sent from the L2
    function exitFromArbitrum(
        bytes32[] calldata proof,
        uint256 index,
        address l2sender,
        address destinationGateway,
        uint256 l2block,
        uint256 l1block,
        uint256 l2timestamp,
        uint256 value,
        bytes calldata data
    ) external;

    /// @notice Returns the current nonce
    /// @return Value of the current nonce
    function nonce() external view returns (uint256);

    /// @notice Withdraws tokens on Mainnet contract to Aave V3 Collector.
    /// @param token Mainnet address of token to withdraw to Collector
    function withdrawToCollector(address token) external;

    /// @notice Rescues the specified token back to the Collector
    /// @param token The address of the ERC20 token to rescue
    function rescueToken(address token) external;

    /// @notice Rescues ETH from the contract back to the Collector
    function rescueEth() external;
}
