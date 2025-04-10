// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IWithGuardian} from "solidity-utils/contracts/access-control/interfaces/IWithGuardian.sol";
import {IRescuable} from "solidity-utils/contracts/utils/Rescuable.sol";
import {ChainIds} from "solidity-utils/contracts/utils/ChainHelpers.sol";
import {MiscPolygon} from "aave-address-book/MiscPolygon.sol";
import {MiscArbitrum} from "aave-address-book/MiscArbitrum.sol";
import {MiscOptimism} from "aave-address-book/MiscOptimism.sol";
import {AaveV3Ethereum, AaveV3EthereumAssets} from "aave-address-book/AaveV3Ethereum.sol";
import {AaveV3Polygon, AaveV3PolygonAssets} from "aave-address-book/AaveV3Polygon.sol";
import {AaveV3Arbitrum, AaveV3ArbitrumAssets} from "aave-address-book/AaveV3Arbitrum.sol";
import {AaveV3Optimism, AaveV3OptimismAssets} from "aave-address-book/AaveV3Optimism.sol";
import {ArbSysMock} from "./ArbSysMock.sol";

import {BridgeSteward, IBridgeSteward} from "src/bridge/BridgeSteward.sol";

/**
 * @title Test for Bridge Steward
 * command: forge test --match-path=tests/bridge/MainnetBridgeSteward.t.sol -vv
 */
contract BridgeStewardTestBase is Test {
    address public owner;
    address public guardian;
    BridgeSteward public steward;

    function setUp() public virtual {
        owner = makeAddr("owner");
        guardian = makeAddr("guardian");

        vm.createSelectFork(vm.rpcUrl("mainnet"), 22225850);
        steward = new BridgeSteward(owner, guardian);
    }
}

contract WithdrawOnPolygonTest is BridgeStewardTestBase {
    address public token = AaveV3PolygonAssets.USDC_UNDERLYING;
    uint256 public amount = 1_000_000e6;

    function test_revertsIf_InvalidChain() public {
        vm.startPrank(owner);

        vm.expectRevert(IBridgeSteward.InvalidChain.selector);
        steward.withdrawOnPolygon(token, amount);
        vm.stopPrank();
    }
}

contract WithdrawOnArbitrumTest is BridgeStewardTestBase {
    address public tokenOnL2 = AaveV3ArbitrumAssets.USDC_UNDERLYING;
    address public tokenOnL1 = AaveV3EthereumAssets.USDC_UNDERLYING;
    // https://arbiscan.io/address/0x096760F208390250649E3e8763348E783AEF5562
    address public gateway = 0x096760F208390250649E3e8763348E783AEF5562;
    uint256 public amount = 1_000_000e6;

    function test_revertsIf_InvalidChain() public {
        vm.startPrank(owner);

        vm.expectRevert(IBridgeSteward.InvalidChain.selector);
        steward.withdrawOnArbitrum(tokenOnL2, tokenOnL1, gateway, amount);
        vm.stopPrank();
    }
}

contract WithdrawOnOptimismTest is BridgeStewardTestBase {
    address public tokenOnL2 = AaveV3OptimismAssets.USDC_UNDERLYING;
    address public tokenOnL1 = AaveV3EthereumAssets.USDC_UNDERLYING;
    uint256 public amount = 1_000_000e6;

    function test_revertsIf_InvalidChain() public {
        vm.startPrank(owner);

        vm.expectRevert(IBridgeSteward.InvalidChain.selector);
        steward.withdrawOnOptimism(tokenOnL2, tokenOnL1, amount);
        vm.stopPrank();
    }
}

contract ExistFromPolygonTest is BridgeStewardTestBase {}

contract StartExitPolBridgeTest is BridgeStewardTestBase {}

contract ExitPolBridgeTest is BridgeStewardTestBase {}

contract ExitFromArbitrumTest is BridgeStewardTestBase {}

contract WithdrawToCollectorTest is BridgeStewardTestBase {
    function test_successful() public {
        uint256 amount = 1_000e6;

        deal(AaveV3EthereumAssets.USDC_UNDERLYING, address(steward), amount);

        uint256 balanceCollectorBefore = IERC20(
            AaveV3EthereumAssets.USDC_UNDERLYING
        ).balanceOf(address(AaveV3Ethereum.COLLECTOR));
        uint256 balanceBridgeBefore = IERC20(
            AaveV3EthereumAssets.USDC_UNDERLYING
        ).balanceOf(address(steward));

        assertEq(balanceBridgeBefore, amount);

        steward.withdrawToCollector(AaveV3EthereumAssets.USDC_UNDERLYING);

        assertEq(
            IERC20(AaveV3EthereumAssets.USDC_UNDERLYING).balanceOf(
                address(AaveV3Ethereum.COLLECTOR)
            ),
            balanceCollectorBefore + amount
        );
        assertEq(
            IERC20(AaveV3EthereumAssets.USDC_UNDERLYING).balanceOf(
                address(steward)
            ),
            0
        );
    }

    function test_successful_eth() public {
        uint256 amount = 1_000e18;

        deal(address(steward), amount);

        uint256 balanceCollectorBefore = payable(
            address(AaveV3Ethereum.COLLECTOR)
        ).balance;
        uint256 balanceBridgeBefore = payable(address(steward)).balance;

        assertEq(balanceBridgeBefore, amount);

        steward.withdrawToCollector(address(0));

        assertEq(
            payable(address(AaveV3Ethereum.COLLECTOR)).balance,
            balanceCollectorBefore + amount
        );
        assertEq(payable(address(steward)).balance, 0);
    }
}

contract EmergencyTokenTransfer is BridgeStewardTestBase {
    function test_successful_permissionless() public {
        assertEq(
            IERC20(AaveV3EthereumAssets.AAVE_UNDERLYING).balanceOf(
                address(steward)
            ),
            0
        );

        uint256 aaveAmount = 1_000e18;

        deal(
            AaveV3EthereumAssets.AAVE_UNDERLYING,
            address(steward),
            aaveAmount
        );

        assertEq(
            IERC20(AaveV3EthereumAssets.AAVE_UNDERLYING).balanceOf(
                address(steward)
            ),
            aaveAmount
        );

        uint256 initialCollectorAaveBalance = IERC20(
            AaveV3EthereumAssets.AAVE_UNDERLYING
        ).balanceOf(address(AaveV3Ethereum.COLLECTOR));

        steward.rescueToken(AaveV3EthereumAssets.AAVE_UNDERLYING);

        assertEq(
            IERC20(AaveV3EthereumAssets.AAVE_UNDERLYING).balanceOf(
                address(AaveV3Ethereum.COLLECTOR)
            ),
            initialCollectorAaveBalance + aaveAmount
        );
        assertEq(
            IERC20(AaveV3EthereumAssets.AAVE_UNDERLYING).balanceOf(
                address(steward)
            ),
            0
        );
    }

    function test_successful_governanceCaller() public {
        assertEq(
            IERC20(AaveV3EthereumAssets.AAVE_UNDERLYING).balanceOf(
                address(steward)
            ),
            0
        );

        uint256 aaveAmount = 1_000e18;

        deal(
            AaveV3EthereumAssets.AAVE_UNDERLYING,
            address(steward),
            aaveAmount
        );

        assertEq(
            IERC20(AaveV3EthereumAssets.AAVE_UNDERLYING).balanceOf(
                address(steward)
            ),
            aaveAmount
        );

        uint256 initialCollectorAaveBalance = IERC20(
            AaveV3EthereumAssets.AAVE_UNDERLYING
        ).balanceOf(address(AaveV3Ethereum.COLLECTOR));

        vm.startPrank(owner);
        steward.rescueToken(AaveV3EthereumAssets.AAVE_UNDERLYING);
        vm.stopPrank();

        assertEq(
            IERC20(AaveV3EthereumAssets.AAVE_UNDERLYING).balanceOf(
                address(AaveV3Ethereum.COLLECTOR)
            ),
            initialCollectorAaveBalance + aaveAmount
        );
        assertEq(
            IERC20(AaveV3EthereumAssets.AAVE_UNDERLYING).balanceOf(
                address(steward)
            ),
            0
        );
    }

    function test_rescueEth() public {
        uint256 mintAmount = 1_000_000e18;
        deal(address(steward), mintAmount);

        uint256 collectorBalanceBefore = address(AaveV3Ethereum.COLLECTOR)
            .balance;

        steward.rescueEth();

        uint256 collectorBalanceAfter = address(AaveV3Ethereum.COLLECTOR)
            .balance;

        assertEq(collectorBalanceAfter - collectorBalanceBefore, mintAmount);
        assertEq(address(steward).balance, 0);
    }
}

contract MaxRescue is BridgeStewardTestBase {
    function test_maxRescue() public {
        assertEq(steward.maxRescue(AaveV3EthereumAssets.USDC_UNDERLYING), 0);

        uint256 mintAmount = 1_000_000e18;
        deal(
            AaveV3EthereumAssets.USDC_UNDERLYING,
            address(steward),
            mintAmount
        );

        assertEq(
            steward.maxRescue(AaveV3EthereumAssets.USDC_UNDERLYING),
            mintAmount
        );
    }
}
