// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ICollector, CollectorUtils as CU} from "aave-helpers/src/CollectorUtils.sol";
import {OwnableWithGuardian} from "solidity-utils/contracts/access-control/OwnableWithGuardian.sol";
import {Multicall} from "openzeppelin-contracts/contracts/utils/Multicall.sol";
import {RescuableBase, IRescuableBase} from "solidity-utils/contracts/utils/RescuableBase.sol";
import {ChainIds} from "solidity-utils/contracts/utils/ChainHelpers.sol";

import {IERC20Polygon} from "./interfaces/IERC20Polygon.sol";
import {IRootChainManager} from "./interfaces/IRootChainManager.sol";
import {IPolEthERC20BridgeSteward} from "./interfaces/IPolEthERC20BridgeSteward.sol";

/**
 * @title PoolExposureSteward
 * @author efecarranza  (Tokenlogic)
 * @notice Manages deposits, withdrawals, and asset migrations between Aave V2 and Aave V3 assets held in the Collector.
 *
 * The contract inherits from `Multicall`. Using the `multicall` function from this contract
 * multiple operations can be bundled into a single transaction.
 *
 * -- Security Considerations
 *
 * -- Pools
 * The pools managed by the steward are allowListed.
 * As v2 pools are deprecated, the steward only implements withdrawals from v2.
 *
 * -- Permissions
 * The contract implements OwnableWithGuardian.
 * The owner will always be the respective network Short Executor (governance).
 * The guardian role will be given to a Financial Service provider of the DAO.
 *
 * While the permitted Service Provider will have full control over the funds, the allowed actions are limited by the contract itself.
 * All token interactions start and end on the Collector, so no funds ever leave the DAO possession at any point in time.
 */
contract PolEthERC20BridgeSteward is
    IPolEthERC20BridgeSteward,
    OwnableWithGuardian,
    RescuableBase,
    Multicall
{
    using SafeERC20 for IERC20;

    /// @inheritdoc IPolEthERC20BridgeSteward
    address public immutable COLLECTOR;

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

    receive() external payable {
        if (block.chainid != ChainIds.MAINNET) revert InvalidChain();

        (bool success, ) = address(COLLECTOR).call{
            value: address(this).balance
        }("");
        if (!success) {
            emit FailedToSendETH();
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
    function exit(address token, bytes calldata burnProof) external {
        if (block.chainid != ChainIds.MAINNET) revert InvalidChain();

        IRootChainManager(_rootChainManager).exit(burnProof);
        uint256 balance = IERC20(token).balanceOf(address(this));

        IERC20(token).safeTransfer(COLLECTOR, balance);
        emit WithdrawToCollector(token, balance);
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
