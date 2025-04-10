// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IWithGuardian} from "solidity-utils/contracts/access-control/interfaces/IWithGuardian.sol";
import {IRescuable} from "solidity-utils/contracts/utils/Rescuable.sol";
import {ChainIds} from "solidity-utils/contracts/utils/ChainHelpers.sol";
import {AaveV3EthereumAssets} from "aave-address-book/AaveV3Ethereum.sol";
import {AaveV3Polygon, AaveV3PolygonAssets} from "aave-address-book/AaveV3Polygon.sol";

import {BridgeSteward, IBridgeSteward} from "src/bridge/BridgeSteward.sol";

/**
 * @title Test for Bridge Steward
 * command: forge test --match-path=tests/bridge/PolygonBridgeSteward.t.sol -vv
 */
contract BridgeStewardTestBase is Test {
    address public owner;
    address public guardian;
    BridgeSteward public steward;

    address public token = AaveV3PolygonAssets.USDC_UNDERLYING;
    uint256 public amount = 1_000_000e6;

    function setUp() public virtual {
        owner = makeAddr("owner");
        guardian = makeAddr("guardian");

        vm.createSelectFork(vm.rpcUrl("polygon"), 70057084);
        steward = new BridgeSteward(owner, guardian);

        vm.prank(AaveV3Polygon.ACL_ADMIN);
        IAccessControl(address(AaveV3Polygon.COLLECTOR)).grantRole(
            "FUNDS_ADMIN",
            address(steward)
        );

        deal(token, address(AaveV3Polygon.COLLECTOR), amount);
    }
}

contract WithdrawOnPolygonTest is BridgeStewardTestBase {
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
        steward = new BridgeSteward(owner, guardian);

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
        emit IBridgeSteward.Bridge(ChainIds.POLYGON, token, amount);
        steward.withdrawOnPolygon(token, amount);

        uint256 balanceAfter = IERC20(token).balanceOf(
            address(AaveV3Polygon.COLLECTOR)
        );
        assertEq(balanceBefore, balanceAfter + amount);
        vm.stopPrank();
    }

    function test_success_pol() public {
        vm.startPrank(guardian);

        token = address(0);
        deal(address(AaveV3Polygon.COLLECTOR), amount);

        uint256 balanceBefore = payable(address(AaveV3Polygon.COLLECTOR))
            .balance;
        vm.expectEmit(true, true, true, true, address(steward));
        emit IBridgeSteward.Bridge(
            ChainIds.POLYGON,
            AaveV3Polygon.COLLECTOR.ETH_MOCK_ADDRESS(),
            amount
        );
        steward.withdrawOnPolygon(token, amount);

        uint256 balanceAfter = payable(address(AaveV3Polygon.COLLECTOR))
            .balance;
        assertEq(balanceBefore, balanceAfter + amount);
        vm.stopPrank();
    }
}

contract WithdrawOnArbitrumTest is BridgeStewardTestBase {
    address public tokenOnL2 = AaveV3PolygonAssets.USDC_UNDERLYING;
    address public tokenOnL1 = AaveV3EthereumAssets.USDC_UNDERLYING;
    // https://arbiscan.io/address/0x096760F208390250649E3e8763348E783AEF5562
    address public gateway = 0x096760F208390250649E3e8763348E783AEF5562;

    function test_revertsIf_InvalidChain() public {
        vm.startPrank(owner);

        vm.expectRevert(IBridgeSteward.InvalidChain.selector);
        steward.withdrawOnArbitrum(tokenOnL2, tokenOnL1, gateway, amount);
        vm.stopPrank();
    }
}

contract WithdrawOnOptimismTest is BridgeStewardTestBase {
    address public tokenOnL2 = AaveV3PolygonAssets.USDC_UNDERLYING;
    address public tokenOnL1 = AaveV3EthereumAssets.USDC_UNDERLYING;

    function test_revertsIf_InvalidChain() public {
        vm.startPrank(owner);

        vm.expectRevert(IBridgeSteward.InvalidChain.selector);
        steward.withdrawOnOptimism(tokenOnL2, tokenOnL1, amount);
        vm.stopPrank();
    }
}

contract ExistFromPolygonTest is BridgeStewardTestBase {
    function test_revertsIf_InvalidChain() public {
        vm.startPrank(owner);

        bytes memory burnProof = hex"1a";

        vm.expectRevert(IBridgeSteward.InvalidChain.selector);
        steward.exitFromPolygon(burnProof);
        vm.stopPrank();
    }
}

contract StartExitPolBridgeTest is BridgeStewardTestBase {
    function test_revertsIf_InvalidChain() public {
        vm.startPrank(owner);

        bytes memory burnProof = hex"1a";

        vm.expectRevert(IBridgeSteward.InvalidChain.selector);
        steward.startExitPolBridge(burnProof);
        vm.stopPrank();
    }
}

contract ExitPolBridgeTest is BridgeStewardTestBase {
    function test_revertsIf_InvalidChain() public {
        vm.startPrank(owner);

        vm.expectRevert(IBridgeSteward.InvalidChain.selector);
        steward.exitPolBridge();
        vm.stopPrank();
    }
}

contract ExitFromArbitrumTest is BridgeStewardTestBase {
    function test_revertsIf_InvalidChain() public {
        vm.startPrank(owner);

        bytes32[] memory proof = new bytes32[](17);
        proof[0] = bytes32(
            0x8f2413401b9e655775aad826103c53ff5ca1ee7ad724eb8c79e9c6daa53a42c1
        );
        proof[1] = bytes32(
            0x28d6fb477c18b08c0fecd8ffbcd6c866388eeebf2cd2c09eb2a6d8a4400b643b
        );
        proof[2] = bytes32(
            0xb1435f7e1cb4a5953e89746da1288a039ffb4f24cacccf315732838e53d6f060
        );
        proof[3] = bytes32(
            0x61db0210d82c6a3a982db41752ab66966ef66f4587bd093dbcc86c79d571f2e2
        );
        proof[4] = bytes32(
            0x89e093bdddd365d65e23655f220d5d106445b3ae37e6371f4d666f3101228c56
        );
        proof[5] = bytes32(
            0x09796038b06aa218c3a098a19c2fe62db5ae65150180256775126c6cc0a7944b
        );
        proof[6] = bytes32(
            0x09e8d829b211a96087ec9e1553d962c7095ea2a516ac5e3d3fc9dfb0883437df
        );
        proof[7] = bytes32(
            0xeb8a59e232457e7992da6dada364130ac0355abd6a3e2de11994cc87dd48e2fd
        );
        proof[8] = bytes32(
            0x7f895c7d5e604507e11dcef280b63fbb176470934d655b9774850e7b4e8a2437
        );
        proof[9] = bytes32(
            0xaa028b33592259e6362db13faf07aad33f79b39ec93c86798e374c1306c622f3
        );
        proof[10] = bytes32(
            0xb6fa41cd3de57f0ba7f178fa0ce164c9f3fd14d9af481bcdee844f1a48b083ed
        );
        proof[11] = bytes32(
            0x5e293ff63182ef6620cdd6aa4f35a1a3fe0d8da195a674f11dafc06043d06719
        );
        proof[12] = bytes32(
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        proof[13] = bytes32(
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        proof[14] = bytes32(
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        proof[15] = bytes32(
            0xc0425084107ea9f7a4118f5ed1e3566cda4e90b550363fc804df1e52ed5f2386
        );
        proof[16] = bytes32(
            0xb43a6b28077d49f37d58c87aec0b51f7bce13b648143f3295385f3b3d5ac3b9b
        );

        vm.expectRevert(IBridgeSteward.InvalidChain.selector);
        steward.exitFromArbitrum(
            proof,
            101373,
            0x09e9222E96E7B4AE2a407B98d48e330053351EEe,
            0xa3A7B6F88361F48403514059F1F16C8E78d60EeC,
            162707774,
            18843894,
            1703278527,
            0,
            hex"2e567b36000000000000000000000000514910771af9ca656af840dff83e8264ecf986ca0000000000000000000000000e6bb71856c5c821d1b83f2c6a9a59a78d5e0712000000000000000000000000464c71f6c2f760dda6093dcb91c24c39e5d6e18c0000000000000000000000000000000000000000000000000031f025da53473500000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000003c7300000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000"
        );

        vm.stopPrank();
    }
}

contract WithdrawToCollectorTest is BridgeStewardTestBase {
    function test_revertsIf_InvalidChain() public {
        vm.expectRevert(IBridgeSteward.InvalidChain.selector);
        steward.withdrawToCollector(AaveV3PolygonAssets.USDC_UNDERLYING);
    }
}

contract EmergencyTokenTransfer is BridgeStewardTestBase {
    function test_successful_permissionless() public {
        assertEq(
            IERC20(AaveV3PolygonAssets.AAVE_UNDERLYING).balanceOf(
                address(steward)
            ),
            0
        );

        uint256 aaveAmount = 1_000e18;

        deal(AaveV3PolygonAssets.AAVE_UNDERLYING, address(steward), aaveAmount);

        assertEq(
            IERC20(AaveV3PolygonAssets.AAVE_UNDERLYING).balanceOf(
                address(steward)
            ),
            aaveAmount
        );

        uint256 initialCollectorAaveBalance = IERC20(
            AaveV3PolygonAssets.AAVE_UNDERLYING
        ).balanceOf(address(AaveV3Polygon.COLLECTOR));

        steward.rescueToken(AaveV3PolygonAssets.AAVE_UNDERLYING);

        assertEq(
            IERC20(AaveV3PolygonAssets.AAVE_UNDERLYING).balanceOf(
                address(AaveV3Polygon.COLLECTOR)
            ),
            initialCollectorAaveBalance + aaveAmount
        );
        assertEq(
            IERC20(AaveV3PolygonAssets.AAVE_UNDERLYING).balanceOf(
                address(steward)
            ),
            0
        );
    }

    function test_successful_governanceCaller() public {
        assertEq(
            IERC20(AaveV3PolygonAssets.AAVE_UNDERLYING).balanceOf(
                address(steward)
            ),
            0
        );

        uint256 aaveAmount = 1_000e18;

        deal(AaveV3PolygonAssets.AAVE_UNDERLYING, address(steward), aaveAmount);

        assertEq(
            IERC20(AaveV3PolygonAssets.AAVE_UNDERLYING).balanceOf(
                address(steward)
            ),
            aaveAmount
        );

        uint256 initialCollectorAaveBalance = IERC20(
            AaveV3PolygonAssets.AAVE_UNDERLYING
        ).balanceOf(address(AaveV3Polygon.COLLECTOR));

        vm.startPrank(owner);
        steward.rescueToken(AaveV3PolygonAssets.AAVE_UNDERLYING);
        vm.stopPrank();

        assertEq(
            IERC20(AaveV3PolygonAssets.AAVE_UNDERLYING).balanceOf(
                address(AaveV3Polygon.COLLECTOR)
            ),
            initialCollectorAaveBalance + aaveAmount
        );
        assertEq(
            IERC20(AaveV3PolygonAssets.AAVE_UNDERLYING).balanceOf(
                address(steward)
            ),
            0
        );
    }

    function test_rescueEth() public {
        uint256 mintAmount = 1_000_000e18;
        deal(address(steward), mintAmount);

        uint256 collectorBalanceBefore = address(AaveV3Polygon.COLLECTOR)
            .balance;

        steward.rescueEth();

        uint256 collectorBalanceAfter = address(AaveV3Polygon.COLLECTOR)
            .balance;

        assertEq(collectorBalanceAfter - collectorBalanceBefore, mintAmount);
        assertEq(address(steward).balance, 0);
    }
}

contract MaxRescue is BridgeStewardTestBase {
    function test_maxRescue() public {
        assertEq(steward.maxRescue(AaveV3PolygonAssets.USDC_UNDERLYING), 0);

        uint256 mintAmount = 1_000_000e18;
        deal(AaveV3PolygonAssets.USDC_UNDERLYING, address(steward), mintAmount);

        assertEq(
            steward.maxRescue(AaveV3PolygonAssets.USDC_UNDERLYING),
            mintAmount
        );
    }
}
