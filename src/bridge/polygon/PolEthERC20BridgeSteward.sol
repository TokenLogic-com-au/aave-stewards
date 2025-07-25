// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {AaveV3PolygonAssets} from "aave-address-book/AaveV3Polygon.sol";
import {ICollector, CollectorUtils as CU} from "aave-helpers/src/CollectorUtils.sol";
import {OwnableWithGuardian} from "solidity-utils/contracts/access-control/OwnableWithGuardian.sol";
import {Multicall} from "openzeppelin-contracts/contracts/utils/Multicall.sol";
import {RescuableBase, IRescuableBase} from "solidity-utils/contracts/utils/RescuableBase.sol";
import {ChainIds} from "solidity-utils/contracts/utils/ChainHelpers.sol";

import {IERC20Polygon} from "./interfaces/IERC20Polygon.sol";
import {IERC20PredicateBurnOnly} from "./interfaces/IERC20PredicateBurnOnly.sol";
import {IRootChainManager} from "./interfaces/IRootChainManager.sol";
import {IWithdrawManager} from "./interfaces/IWithdrawManager.sol";
import {IWPol} from "./interfaces/IWPol.sol";
import {IPolEthERC20BridgeSteward} from "./interfaces/IPolEthERC20BridgeSteward.sol";

/**
 * @title PolEthERC20BridgeSteward
 * @author efecarranza  (Tokenlogic)
 * @notice Bridges funds held in Polygon's Collector to Mainnet's Collector.
 *
 * The contract inherits from `Multicall`. Using the `multicall` function from this contract
 * multiple operations can be bundled into a single transaction.
 *
 * -- Security Considerations
 *
 * The owner or guardian can bridge all funds from Polygon's Collector to Mainnet.
 * If the POL token is migrated (as it happened on September 4th, 2024 from MATIC to POL) then the tokens can get stuck until rescued.
 * The function `bridgePol()` must never be called via `multicall` as Polygon rate-limits bridges by the number of events emitted in
 * a single transaction. `bridgePol()` must always be called alone and ensuring that the number of events in the trasaction is less than 10,
 * even counting the events emitted to transfer from the Collector to the bridge contract.
 *
 * -- Permissions
 * The contract implements OwnableWithGuardian.
 * The owner will always be the respective network Level 1 Executor (governance).
 * The guardian role will be given to a Financial Service provider of the DAO.
 *
 * While the permitted Service Provider will have full control over the funds, the allowed actions are limited by the contract itself.
 * All token interactions start and end on the Collector, so no funds ever leave the DAO's possession at any point in time.
 */
contract PolEthERC20BridgeSteward is
    IPolEthERC20BridgeSteward,
    OwnableWithGuardian,
    RescuableBase,
    Multicall
{
    using SafeERC20 for IERC20;

    /// @inheritdoc IPolEthERC20BridgeSteward
    address public constant ERC20_PREDICATE_BURN =
        0x158d5fa3Ef8e4dDA8a5367deCF76b94E7efFCe95;

    /// @inheritdoc IPolEthERC20BridgeSteward
    address public constant WITHDRAW_MANAGER =
        0x2A88696e0fFA76bAA1338F2C74497cC013495922;

    /// @inheritdoc IPolEthERC20BridgeSteward
    address public constant POL_MAINNET =
        0x455e53CBB86018Ac2B8092FdCd39d8444aFFC3F6;

    /// @inheritdoc IPolEthERC20BridgeSteward
    address public constant POL_POLYGON =
        0x0000000000000000000000000000000000001010;

    /// @inheritdoc IPolEthERC20BridgeSteward
    address public immutable COLLECTOR;

    /// @inheritdoc IPolEthERC20BridgeSteward
    address public _rootChainManager =
        0xA0c68C638235ee32657e8f720a23ceC1bFc77C77;

    /// @param initialOwner The owner of the contract upon deployment
    /// @param initialGuardian The guardian of the contract upon deployment
    /// @param collector The address of the Aave Collector on the deployed chain
    constructor(
        address initialOwner,
        address initialGuardian,
        address collector
    ) OwnableWithGuardian(initialOwner, initialGuardian) {
        COLLECTOR = collector;
    }

    /// @dev Allows the contract to receive ETH on Mainnet and POL on Polygon
    receive() external payable {
        if (block.chainid == ChainIds.MAINNET) {
            (bool success, ) = address(COLLECTOR).call{
                value: address(this).balance
            }("");
            if (!success) {
                emit FailedToSendETH();
            }
        }
    }

    /// @inheritdoc IPolEthERC20BridgeSteward
    function bridge(
        address token,
        uint256 amount
    ) external onlyOwnerOrGuardian {
        if (block.chainid != ChainIds.POLYGON) revert InvalidChain();

        IERC20Polygon(token).withdraw(amount);
        emit Bridge(token, amount);
    }

    /// @inheritdoc IPolEthERC20BridgeSteward
    function bridgePol(uint256 amount, bool unwrap) external onlyOwner {
        if (block.chainid != ChainIds.POLYGON) revert InvalidChain();

        if (unwrap) {
            IWPol(AaveV3PolygonAssets.WPOL_UNDERLYING).withdraw(amount);
        }

        IERC20Polygon(POL_POLYGON).withdraw{value: amount}(amount);
        emit Bridge(POL_POLYGON, amount);
    }

    /// @inheritdoc IPolEthERC20BridgeSteward
    function exit(address token, bytes calldata burnProof) external {
        if (block.chainid != ChainIds.MAINNET) revert InvalidChain();

        IRootChainManager(_rootChainManager).exit(burnProof);
        uint256 balance = IERC20(token).balanceOf(address(this));

        IERC20(token).safeTransfer(COLLECTOR, balance);
        emit WithdrawToCollector(token, balance);
    }

    /// @inheritdoc IPolEthERC20BridgeSteward
    function confirmPolExit(bytes calldata burnProof) external {
        if (block.chainid != ChainIds.MAINNET) revert InvalidChain();

        IERC20PredicateBurnOnly(ERC20_PREDICATE_BURN).startExitWithBurntTokens(
            burnProof
        );
        emit ConfirmExit(burnProof);
    }

    /// @inheritdoc IPolEthERC20BridgeSteward
    function exitPol() external {
        if (block.chainid != ChainIds.MAINNET) revert InvalidChain();

        IWithdrawManager(WITHDRAW_MANAGER).processExits(POL_MAINNET);
        uint256 balance = IERC20(POL_MAINNET).balanceOf(address(this));

        IERC20(POL_MAINNET).safeTransfer(COLLECTOR, balance);
        emit WithdrawToCollector(POL_MAINNET, balance);
    }

    /// @inheritdoc IPolEthERC20BridgeSteward
    function rescueToken(address token) external {
        _emergencyTokenTransfer(token, COLLECTOR, type(uint256).max);
    }

    /// @inheritdoc IPolEthERC20BridgeSteward
    function rescueEth() external {
        _emergencyEtherTransfer(COLLECTOR, address(this).balance);
    }

    /// @inheritdoc IRescuableBase
    function maxRescue(
        address token
    ) public view override(RescuableBase) returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    /// @inheritdoc IPolEthERC20BridgeSteward
    function setRootChainManager(address rootChainManager) external onlyOwner {
        if (block.chainid != ChainIds.MAINNET) revert InvalidChain();

        address oldRootChainManager = _rootChainManager;
        _rootChainManager = rootChainManager;

        emit RootChainManagerUpdated(rootChainManager, oldRootChainManager);
    }

    /// @inheritdoc IPolEthERC20BridgeSteward
    function isTokenMapped(address l2token) external view returns (bool) {
        if (block.chainid != ChainIds.MAINNET) revert InvalidChain();

        return
            IRootChainManager(_rootChainManager).childToRootToken(l2token) !=
            address(0);
    }
}
