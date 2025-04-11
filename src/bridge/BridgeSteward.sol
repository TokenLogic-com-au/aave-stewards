// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ICollector} from "aave-helpers/src/CollectorUtils.sol";
import {OwnableWithGuardian} from "solidity-utils/contracts/access-control/OwnableWithGuardian.sol";
import {RescuableBase, IRescuableBase} from "solidity-utils/contracts/utils/RescuableBase.sol";
import {ChainIds} from "solidity-utils/contracts/utils/ChainHelpers.sol";
import {Multicall} from "openzeppelin-contracts/contracts/utils/Multicall.sol";

import {AaveV3Ethereum} from "aave-address-book/AaveV3Ethereum.sol";
import {AaveV3Polygon} from "aave-address-book/AaveV3Polygon.sol";
import {AaveV3Arbitrum} from "aave-address-book/AaveV3Arbitrum.sol";
import {AaveV3Optimism} from "aave-address-book/AaveV3Optimism.sol";

import {IBridgeSteward} from "./interfaces/IBridgeSteward.sol";
import {IERC20Polygon} from "./interfaces/IERC20Polygon.sol";
import {IERC20PredicateBurnOnly} from "./interfaces/IERC20PredicateBurnOnly.sol";
import {IPolWithdrawManager} from "./interfaces/IPolWithdrawManager.sol";
import {IRootChainManager} from "./interfaces/IRootChainManager.sol";
import {IArbitrumGateway} from "./interfaces/IArbitrumGateway.sol";
import {IArbitrumOutbox} from "./interfaces/IArbitrumOutbox.sol";
import {IOptimismStandardBridge} from "./interfaces/IOptimismStandardBridge.sol";

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
    using SafeERC20 for IERC20;

    // https://etherscan.io/address/0xA0c68C638235ee32657e8f720a23ceC1bFc77C77
    /// @inheritdoc IBridgeSteward
    address public constant POL_ROOT_CHAIN_MANAGER =
        0xA0c68C638235ee32657e8f720a23ceC1bFc77C77;

    /// @inheritdoc IBridgeSteward
    address public constant POL_ERC20_PREDICATE_BURN =
        0x158d5fa3Ef8e4dDA8a5367deCF76b94E7efFCe95;

    /// @inheritdoc IBridgeSteward
    address public constant POL_WITHDRAW_MANAGER =
        0x2A88696e0fFA76bAA1338F2C74497cC013495922;

    /// @inheritdoc IBridgeSteward
    address public constant POL_MATIC_MAINNET =
        0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0;

    /// @inheritdoc IBridgeSteward
    address public constant POL_MATIC_POLYGON =
        0x0000000000000000000000000000000000001010;

    // https://etherscan.io/address/0x0B9857ae2D4A3DBe74ffE1d7DF045bb7F96E4840
    /// @inheritdoc IBridgeSteward
    address public constant ARB_OUTBOX =
        0x0B9857ae2D4A3DBe74ffE1d7DF045bb7F96E4840;

    // https://optimistic.etherscan.io/address/0x4200000000000000000000000000000000000010
    /// @inheritdoc IBridgeSteward
    address public constant OPT_STANDARD_BRIDGE =
        0x4200000000000000000000000000000000000010;
    uint256 private _nonce;

    constructor(
        address initialOwner,
        address initialGuardian
    ) OwnableWithGuardian(initialOwner, initialGuardian) {}

    receive() external payable {}

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
        if (token == address(0)) {
            token = AaveV3Polygon.COLLECTOR.ETH_MOCK_ADDRESS();
        }
        AaveV3Polygon.COLLECTOR.transfer(IERC20(token), address(this), amount);

        if (token == AaveV3Polygon.COLLECTOR.ETH_MOCK_ADDRESS()) {
            IERC20Polygon(POL_MATIC_POLYGON).withdraw{value: amount}(amount);
        } else {
            IERC20Polygon(token).withdraw(amount);
        }

        emit Bridge(ChainIds.POLYGON, token, amount);
    }

    /// @inheritdoc IBridgeSteward
    function withdrawOnArbitrum(
        address tokenOnL2,
        address tokenOnL1,
        address gateway,
        uint256 amount
    ) external onlyOwnerOrGuardian checkChain(ChainIds.ARBITRUM) {
        AaveV3Arbitrum.COLLECTOR.transfer(
            IERC20(tokenOnL2),
            address(this),
            amount
        );

        IERC20(tokenOnL2).forceApprove(gateway, amount);

        IArbitrumGateway(gateway).outboundTransfer(
            tokenOnL1,
            address(AaveV3Ethereum.COLLECTOR),
            amount,
            ""
        );

        emit Bridge(ChainIds.ARBITRUM, tokenOnL2, amount);
    }

    /// @inheritdoc IBridgeSteward
    function withdrawOnOptimism(
        address tokenOnL2,
        address tokenOnL1,
        uint256 amount
    ) external onlyOwnerOrGuardian checkChain(ChainIds.OPTIMISM) {
        AaveV3Optimism.COLLECTOR.transfer(
            IERC20(tokenOnL2),
            address(this),
            amount
        );

        IERC20(tokenOnL2).forceApprove(OPT_STANDARD_BRIDGE, amount);
        IOptimismStandardBridge(OPT_STANDARD_BRIDGE).bridgeERC20To(
            tokenOnL2,
            tokenOnL1,
            address(AaveV3Ethereum.COLLECTOR),
            amount,
            250000,
            abi.encodePacked(_nonce)
        );

        _nonce++;

        emit Bridge(ChainIds.OPTIMISM, tokenOnL2, amount);
    }

    /// @inheritdoc IBridgeSteward
    function exitFromPolygon(
        bytes calldata burnProof
    ) external checkChain(ChainIds.MAINNET) {
        IRootChainManager(POL_ROOT_CHAIN_MANAGER).exit(burnProof);
        emit Exit(ChainIds.POLYGON, burnProof);
    }

    /// @inheritdoc IBridgeSteward
    function startExitPolBridge(
        bytes calldata burnProof
    ) external checkChain(ChainIds.MAINNET) {
        IERC20PredicateBurnOnly(POL_ERC20_PREDICATE_BURN)
            .startExitWithBurntTokens(burnProof);

        emit Exit(ChainIds.POLYGON, burnProof);
    }

    /// @inheritdoc IBridgeSteward
    function exitPolBridge() external checkChain(ChainIds.MAINNET) {
        IPolWithdrawManager(POL_WITHDRAW_MANAGER).processExits(
            POL_MATIC_MAINNET
        );

        emit Exit(ChainIds.POLYGON, abi.encode(POL_MATIC_MAINNET));
    }

    /// @inheritdoc IBridgeSteward
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
    ) external checkChain(ChainIds.MAINNET) {
        IArbitrumOutbox(ARB_OUTBOX).executeTransaction(
            proof,
            index,
            l2sender,
            destinationGateway,
            l2block,
            l1block,
            l2timestamp,
            value,
            data
        );

        emit Exit(
            ChainIds.ARBITRUM,
            abi.encode(
                l2sender,
                destinationGateway,
                l2block,
                l1block,
                value,
                data
            )
        );
    }

    /// @inheritdoc IBridgeSteward
    function withdrawToCollector(
        address token
    ) external checkChain(ChainIds.MAINNET) {
        uint256 balance;
        if (token == address(0)) {
            balance = payable(address(this)).balance;
            payable(address(AaveV3Ethereum.COLLECTOR)).call{value: balance}("");
        } else {
            balance = IERC20(token).balanceOf(address(this));
            IERC20(token).safeTransfer(
                address(AaveV3Ethereum.COLLECTOR),
                balance
            );
        }

        emit WithdrawToCollector(token, balance);
    }

    /// @inheritdoc IBridgeSteward
    function nonce() external view returns (uint256) {
        return _nonce;
    }

    /// @inheritdoc IBridgeSteward
    function rescueToken(address token) external {
        address collector;
        if (block.chainid == ChainIds.MAINNET) {
            collector = address(AaveV3Ethereum.COLLECTOR);
        } else if (block.chainid == ChainIds.ARBITRUM) {
            collector = address(AaveV3Arbitrum.COLLECTOR);
        } else if (block.chainid == ChainIds.OPTIMISM) {
            collector = address(AaveV3Optimism.COLLECTOR);
        } else if (block.chainid == ChainIds.POLYGON) {
            collector = address(AaveV3Polygon.COLLECTOR);
        } else {
            revert InvalidChain();
        }

        _emergencyTokenTransfer(
            token,
            collector,
            IERC20(token).balanceOf(address(this))
        );
    }

    /// @inheritdoc IBridgeSteward
    function rescueEth() external {
        address collector;
        if (block.chainid == ChainIds.MAINNET) {
            collector = address(AaveV3Ethereum.COLLECTOR);
        } else if (block.chainid == ChainIds.ARBITRUM) {
            collector = address(AaveV3Arbitrum.COLLECTOR);
        } else if (block.chainid == ChainIds.OPTIMISM) {
            collector = address(AaveV3Optimism.COLLECTOR);
        } else if (block.chainid == ChainIds.POLYGON) {
            collector = address(AaveV3Polygon.COLLECTOR);
        } else {
            revert InvalidChain();
        }

        _emergencyEtherTransfer(collector, address(this).balance);
    }

    /// @inheritdoc IRescuableBase
    function maxRescue(
        address token
    ) public view override(RescuableBase) returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
