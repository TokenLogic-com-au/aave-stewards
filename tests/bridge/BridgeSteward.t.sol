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
import {AaveV3EthereumAssets} from "aave-address-book/AaveV3Ethereum.sol";
import {AaveV3Polygon, AaveV3PolygonAssets} from "aave-address-book/AaveV3Polygon.sol";
import {AaveV3Arbitrum, AaveV3ArbitrumAssets} from "aave-address-book/AaveV3Arbitrum.sol";
import {AaveV3Optimism, AaveV3OptimismAssets} from "aave-address-book/AaveV3Optimism.sol";
import {ArbSysMock} from "./ArbSysMock.sol";

import {BridgeSteward, IBridgeSteward} from "src/bridge/BridgeSteward.sol";

/**
 * @title Test for Bridge Steward
 * command: forge test --match-path=tests/bridge/BridgeSteward.t.sol -vv
 */
contract BridgeStewardTestBase is Test {
    address public owner;
    address public guardian;
    BridgeSteward public steward;

    function setUp() public virtual {
        owner = makeAddr("owner");
        guardian = makeAddr("guardian");
    }
}

contract WithdrawOnPolygonTest is BridgeStewardTestBase {
    address public token = AaveV3PolygonAssets.USDC_UNDERLYING;
    uint256 public amount = 1_000_000e6;

    function setUp() public override {
        super.setUp();

        vm.createSelectFork(vm.rpcUrl("polygon"), 70057084);
        steward = new BridgeSteward(
            owner,
            guardian,
            address(AaveV3Polygon.COLLECTOR)
        );

        vm.prank(AaveV3Polygon.ACL_ADMIN);
        IAccessControl(address(AaveV3Polygon.COLLECTOR)).grantRole(
            "FUNDS_ADMIN",
            address(steward)
        );

        vm.startPrank(Ownable(MiscPolygon.AAVE_POL_ETH_BRIDGE).owner());
        Ownable(MiscPolygon.AAVE_POL_ETH_BRIDGE).transferOwnership(
            address(steward)
        );
        vm.stopPrank();

        deal(token, address(AaveV3Polygon.COLLECTOR), amount);
    }

    function test_revertsIf_NotOwnerOrGuardian() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IWithGuardian.OnlyGuardianOrOwnerInvalidCaller.selector,
                address(this)
            )
        );
        steward.withdrawOnPolygon(token, amount);
        vm.stopPrank();
    }

    function test_revertsIf_InvalidChain() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), 22225850);
        steward = new BridgeSteward(
            owner,
            guardian,
            address(AaveV3Polygon.COLLECTOR)
        );

        vm.startPrank(owner);

        vm.expectRevert(IBridgeSteward.InvalidChain.selector);
        steward.withdrawOnPolygon(token, amount);
        vm.stopPrank();
    }

    function test_success() public {
        vm.startPrank(guardian);

        uint256 balanceBefore = IERC20(token).balanceOf(
            address(AaveV3Polygon.COLLECTOR)
        );
        vm.expectEmit(true, true, true, true, address(steward));
        emit IBridgeSteward.TokenBridged(
            ChainIds.POLYGON,
            ChainIds.ETHEREUM,
            token,
            amount
        );
        steward.withdrawOnPolygon(token, amount);

        uint256 balanceAfter = IERC20(token).balanceOf(
            address(AaveV3Polygon.COLLECTOR)
        );
        assertEq(balanceBefore, balanceAfter + amount);
        vm.stopPrank();
    }
}

contract WithdrawOnArbitrumTest is BridgeStewardTestBase {
    address public tokenOnL2 = AaveV3ArbitrumAssets.USDC_UNDERLYING;
    address public tokenOnL1 = AaveV3EthereumAssets.USDC_UNDERLYING;
    // https://arbiscan.io/address/0x096760F208390250649E3e8763348E783AEF5562
    address public gateway = 0x096760F208390250649E3e8763348E783AEF5562;
    uint256 public amount = 1_000_000e6;

    function setUp() public override {
        super.setUp();

        vm.createSelectFork(vm.rpcUrl("arbitrum"), 324309655);
        steward = new BridgeSteward(
            owner,
            guardian,
            address(AaveV3Arbitrum.COLLECTOR)
        );

        vm.prank(AaveV3Arbitrum.ACL_ADMIN);
        IAccessControl(address(AaveV3Arbitrum.COLLECTOR)).grantRole(
            "FUNDS_ADMIN",
            address(steward)
        );

        vm.startPrank(Ownable(MiscArbitrum.AAVE_ARB_ETH_BRIDGE).owner());
        Ownable(MiscArbitrum.AAVE_ARB_ETH_BRIDGE).transferOwnership(
            address(steward)
        );
        vm.stopPrank();

        deal(tokenOnL2, address(AaveV3Arbitrum.COLLECTOR), amount);

        ArbSysMock arbsys = new ArbSysMock();
        vm.etch(
            address(0x0000000000000000000000000000000000000064),
            address(arbsys).code
        );
    }

    function test_revertsIf_NotOwnerOrGuardian() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IWithGuardian.OnlyGuardianOrOwnerInvalidCaller.selector,
                address(this)
            )
        );
        steward.withdrawOnArbitrum(tokenOnL2, tokenOnL1, gateway, amount);
        vm.stopPrank();
    }

    function test_revertsIf_InvalidChain() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), 22225850);
        steward = new BridgeSteward(
            owner,
            guardian,
            address(AaveV3Arbitrum.COLLECTOR)
        );

        vm.startPrank(owner);

        vm.expectRevert(IBridgeSteward.InvalidChain.selector);
        steward.withdrawOnArbitrum(tokenOnL2, tokenOnL1, gateway, amount);
        vm.stopPrank();
    }

    function test_success() public {
        vm.startPrank(guardian);

        uint256 balanceBefore = IERC20(tokenOnL2).balanceOf(
            address(AaveV3Arbitrum.COLLECTOR)
        );
        vm.expectEmit(true, true, true, true, address(steward));
        emit IBridgeSteward.TokenBridged(
            ChainIds.ARBITRUM,
            ChainIds.ETHEREUM,
            tokenOnL2,
            amount
        );
        steward.withdrawOnArbitrum(tokenOnL2, tokenOnL1, gateway, amount);

        uint256 balanceAfter = IERC20(tokenOnL2).balanceOf(
            address(AaveV3Arbitrum.COLLECTOR)
        );
        assertEq(balanceBefore, balanceAfter + amount);
        vm.stopPrank();
    }
}

contract WithdrawOnOptimismTest is BridgeStewardTestBase {
    address public tokenOnL2 = AaveV3OptimismAssets.USDC_UNDERLYING;
    address public tokenOnL1 = AaveV3EthereumAssets.USDC_UNDERLYING;
    uint256 public amount = 1_000_000e6;

    function setUp() public override {
        super.setUp();

        vm.createSelectFork(vm.rpcUrl("optimism"), 134271208);
        steward = new BridgeSteward(
            owner,
            guardian,
            address(AaveV3Optimism.COLLECTOR)
        );

        vm.prank(AaveV3Optimism.ACL_ADMIN);
        IAccessControl(address(AaveV3Optimism.COLLECTOR)).grantRole(
            "FUNDS_ADMIN",
            address(steward)
        );

        vm.startPrank(Ownable(MiscOptimism.AAVE_OPT_ETH_BRIDGE).owner());
        Ownable(MiscOptimism.AAVE_OPT_ETH_BRIDGE).transferOwnership(
            address(steward)
        );
        vm.stopPrank();

        deal(tokenOnL2, address(AaveV3Optimism.COLLECTOR), amount);
    }

    function test_revertsIf_NotOwnerOrGuardian() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IWithGuardian.OnlyGuardianOrOwnerInvalidCaller.selector,
                address(this)
            )
        );
        steward.withdrawOnOptimism(tokenOnL2, tokenOnL1, amount);
        vm.stopPrank();
    }

    function test_revertsIf_InvalidChain() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), 22225850);
        steward = new BridgeSteward(
            owner,
            guardian,
            address(AaveV3Optimism.COLLECTOR)
        );

        vm.startPrank(owner);

        vm.expectRevert(IBridgeSteward.InvalidChain.selector);
        steward.withdrawOnOptimism(tokenOnL2, tokenOnL1, amount);
        vm.stopPrank();
    }

    function test_success() public {
        vm.startPrank(guardian);

        uint256 balanceBefore = IERC20(tokenOnL2).balanceOf(
            address(AaveV3Optimism.COLLECTOR)
        );
        vm.expectEmit(true, true, true, true, address(steward));
        emit IBridgeSteward.TokenBridged(
            ChainIds.OPTIMISM,
            ChainIds.ETHEREUM,
            tokenOnL2,
            amount
        );
        steward.withdrawOnOptimism(tokenOnL2, tokenOnL1, amount);

        uint256 balanceAfter = IERC20(tokenOnL2).balanceOf(
            address(AaveV3Optimism.COLLECTOR)
        );
        assertEq(balanceBefore, balanceAfter + amount);
        vm.stopPrank();
    }
}
