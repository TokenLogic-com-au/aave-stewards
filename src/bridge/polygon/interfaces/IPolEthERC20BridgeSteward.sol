// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ICollector} from "aave-helpers/src/CollectorUtils.sol";

/// @title IPolEthERC20BridgeSteward
/// @author efecarranza.eth (TokenLogic)
/// @notice Defines the behaviour of a IPolEthERC20BridgeSteward
interface IPolEthERC20BridgeSteward {
    /// @notice Emitted when an ERC20 token is bridged from Polygon
    /// @param token Address of the ERC20 token on Polygon
    /// @param amount The amount of ERC20 token to bridge
    event Bridge(address indexed token, uint256 amount);

    /// @dev Emitted when the bridge transaction is confirmed
    event ConfirmExit(bytes proof);

    /// @dev Emitted when the Root Chain Manager is updated on Mainnet
    /// @param rootChainManager Address of the new RootChainManager address
    /// @param oldRootChainManager Address of the old RootChainManager address
    event RootChainManagerUpdated(
        address rootChainManager,
        address oldRootChainManager
    );

    /// @notice Emitted when a token is allowed/disallowed for bridging
    /// @param token Address of the token to bridge
    /// @param allowed Whether it is allowed/disallowed
    event SetTokenAllowed(address indexed token, bool allowed);

    /// @notice Emitted when an ERC20 token is withdrawn from Mainnet bridge to the Collector
    /// @param token Address of the ERC20 token on Mainnet
    /// @param amount The amount of ERC20 token to transfer
    event WithdrawToCollector(address indexed token, uint256 amount);

    /// @dev Function cannot be called on this network
    error InvalidChain();

    /// @dev Provided address cannot be the zero-address
    error InvalidZeroAddress();

    /// @dev Could not withdraw ETH to the Collector
    error FailedToSendETH();

    /// @dev Token has not been approved for bridging
    error TokenNotAllowed();

    /// This function withdraws an ERC20 token from Polygon to Mainnet. exit() needs
    /// to be called on mainnet with the corresponding burnProof in order to complete.
    /// @notice Polygon only. Function will revert if called from other network.
    /// @param token Polygon address of ERC20 token to withdraw
    /// @param amount Amount of tokens to withdraw
    function bridge(address token, uint256 amount) external;

    /// This function withdraws POL from Polygon to Mainnet. confirmPolExit() needs
    /// to be called on Mainnet with the corresponding burnProof in order to confirm withdrawal.
    /// Then exitPol() needs to be called to do actual withdrawal of tokens.
    /// @notice Polygon only. Function will revert if called from other network.
    /// @param amount Amount of tokens to withdraw
    /// @param unwrap Whether to unwrap wPOL into POL prior to bridging
    function bridgePol(uint256 amount, bool unwrap) external;

    /// This function completes the withdrawal process from Polygon to Mainnet.
    /// Burn proof is generated via API. Please see README.md
    /// @notice Mainnet only. Function will revert if called from other network.
    /// Use ETH_MOCK_ADDRESS to withdraw ETH.
    /// @param token Mainnet address of ERC20 token to withdraw
    /// @param burnProof Burn proof generated via API
    function exit(address token, bytes calldata burnProof) external;

    /// This function confirms the POL withdrawal process from Polygon to Mainnet (Step 2 of 3)
    /// Burn proof is generated via API. Please see README.md
    /// @notice Mainnet only. Function will revert if called from other network.
    /// @param burnProof Burn proof generated via API.
    function confirmPolExit(bytes calldata burnProof) external;

    /// This function completes the POL withdrawal process from Polygon to Mainnet.
    /// @notice Mainnet only. Function will revert if called from other network.
    function exitPol() external;

    /// @notice Rescues the specified token back to the Collector
    /// @param token The address of the ERC20 token to rescue
    function rescueToken(address token) external;

    /// @notice Rescues ETH from the contract back to the Collector
    function rescueEth() external;

    /// @notice Sets a token to allowed/disallowed for bridging
    /// @dev Only callable on Polygon.
    /// @param token Address of the token to set status for
    /// @param allowed Whether token is allowed/disallowed
    function setTokenAllowed(address token, bool allowed) external;

    /// @notice Sets the RootChainManager
    /// @param rootChainManager Address of the Polygon Root Chain Manager on Mainnet
    function setRootChainManager(address rootChainManager) external;

    /// @notice Returns ETH mock address in order to withdraw ether accordingly on Mainnet
    function ETH_MOCK_ADDRESS() external view returns (address);

    /// @notice Returns instance of Aave V3 Collector
    function COLLECTOR() external view returns (address);

    /// @notice Returns the address of the Mainnet contract to exit the burn from
    function _rootChainManager() external view returns (address);

    /// @notice Returns whether a token can be bridged
    function allowedTokens(address token) external view returns (bool);

    /// @dev The mainnet address of the Predicate contract to confirm withdrawal
    function ERC20_PREDICATE_BURN() external view returns (address);

    /// @dev The mainnet address of the withdrawal contract to exit the bridge
    function WITHDRAW_MANAGER() external view returns (address);

    /// @dev The mainnet address of the POL token
    function POL_MAINNET() external view returns (address);

    /// @dev The polygon address of the POL token
    function POL_POLYGON() external view returns (address);

    /// This function checks whether the L2 token to L1 token mapping exists.
    /// If the mapping doesn't exist, DO NOT BRIDGE from Polygon.
    /// @notice Call on Mainnet only.
    /// @param l2token Address of the token on Polygon.
    /// @return Boolean denoting whether mapping exists or not.
    function isTokenMapped(address l2token) external view returns (bool);
}
