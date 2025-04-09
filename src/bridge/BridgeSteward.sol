// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ICollector} from "aave-helpers/src/CollectorUtils.sol";
import {OwnableWithGuardian} from "solidity-utils/contracts/access-control/OwnableWithGuardian.sol";
import {RescuableBase, IRescuableBase} from "solidity-utils/contracts/utils/RescuableBase.sol";
import {ChainIds} from "solidity-utils/contracts/utils/ChainHelpers.sol";
import {Multicall} from "openzeppelin-contracts/contracts/utils/Multicall.sol";

import {MiscArbitrum} from "aave-address-book/MiscArbitrum.sol";
import {MiscOptimism} from "aave-address-book/MiscOptimism.sol";
import {MiscPolygon} from "aave-address-book/MiscPolygon.sol";
import {IAavePolEthERC20Bridge} from "aave-helpers/src/bridges/polygon/IAavePolEthERC20Bridge.sol";
import {IAaveArbEthERC20Bridge} from "aave-helpers/src/bridges/arbitrum/IAaveArbEthERC20Bridge.sol";
import {IAaveOpEthERC20Bridge} from "aave-helpers/src/bridges/optimism/IAaveOpEthERC20Bridge.sol";

import {IBridgeSteward} from "./interfaces/IBridgeSteward.sol";

/**
 * @title BridgeSteward
 * @author LucasWong (Tokenlogic)
 * @notice Manages bridging token from L2 networks(Arbitrum, Optimism and Polygon) to Mainnet.
 *
 * The contract inherits from `Multicall`. Using the `multicall` function from this contract
 * multiple operations can be bundled into a single transaction.
 *
 * -- Security Considerations
 *
 * -- Permissions
 * The contract implements OwnableWithGuardian.
 * The owner will always be the respective network Short Executor (governance).
 * The guardian role will be given to a Financial Service provider of the DAO.
 *
 * While the permitted Service Provider will have full control over the funds, the allowed actions are limited by the contract itself.
 * All token interactions start and end on the Collector, so no funds ever leave the DAO possession at any point in time.
 */
contract BridgeSteward is
    IBridgeSteward,
    OwnableWithGuardian,
    RescuableBase,
    Multicall
{
    /// @inheritdoc IBridgeSteward
    ICollector public immutable COLLECTOR;

    constructor(
        address initialOwner,
        address initialGuardian,
        address collector
    ) OwnableWithGuardian(initialOwner, initialGuardian) {
        COLLECTOR = ICollector(collector);
    }

    modifier checkChain(uint256 chainId) {
        if (block.chainid != chainId) {
            revert InvalidChain();
        }
        _;
    }

    /// @inheritdoc IBridgeSteward
    function withdrawOnPolygon(
        address token,
        uint256 amount
    ) external onlyOwnerOrGuardian checkChain(ChainIds.POLYGON) {
        COLLECTOR.transfer(
            IERC20(token),
            MiscPolygon.AAVE_POL_ETH_BRIDGE,
            amount
        );
        IAavePolEthERC20Bridge(MiscPolygon.AAVE_POL_ETH_BRIDGE).bridge(
            token,
            amount
        );

        emit TokenBridged(ChainIds.POLYGON, ChainIds.MAINNET, token, amount);
    }

    /// @inheritdoc IBridgeSteward
    function withdrawOnArbitrum(
        address tokenOnL2,
        address tokenOnL1,
        address gateway,
        uint256 amount
    ) external onlyOwnerOrGuardian checkChain(ChainIds.ARBITRUM) {
        COLLECTOR.transfer(
            IERC20(tokenOnL2),
            MiscArbitrum.AAVE_ARB_ETH_BRIDGE,
            amount
        );
        IAaveArbEthERC20Bridge(MiscArbitrum.AAVE_ARB_ETH_BRIDGE).bridge(
            tokenOnL2,
            tokenOnL1,
            gateway,
            amount
        );

        emit TokenBridged(
            ChainIds.ARBITRUM,
            ChainIds.MAINNET,
            tokenOnL2,
            amount
        );
    }

    /// @inheritdoc IBridgeSteward
    function withdrawOnOptimism(
        address tokenOnL2,
        address tokenOnL1,
        uint256 amount
    ) external onlyOwnerOrGuardian checkChain(ChainIds.OPTIMISM) {
        COLLECTOR.transfer(
            IERC20(tokenOnL2),
            MiscOptimism.AAVE_OPT_ETH_BRIDGE,
            amount
        );
        IAaveOpEthERC20Bridge(MiscOptimism.AAVE_OPT_ETH_BRIDGE).bridge(
            tokenOnL2,
            tokenOnL1,
            amount
        );

        emit TokenBridged(
            ChainIds.OPTIMISM,
            ChainIds.MAINNET,
            tokenOnL2,
            amount
        );
    }

    /// @inheritdoc IBridgeSteward
    function rescueToken(address token) external {
        _emergencyTokenTransfer(token, address(COLLECTOR), type(uint256).max);
    }

    /// @inheritdoc IBridgeSteward
    function rescueEth() external {
        _emergencyEtherTransfer(address(COLLECTOR), address(this).balance);
    }

    /// @inheritdoc IRescuableBase
    function maxRescue(
        address token
    ) public view override(RescuableBase) returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
