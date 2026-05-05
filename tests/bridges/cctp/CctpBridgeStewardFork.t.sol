// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {AaveV3Arbitrum} from 'aave-address-book/AaveV3Arbitrum.sol';
import {AaveV3Base} from 'aave-address-book/AaveV3Base.sol';
import {AaveV3Optimism} from 'aave-address-book/AaveV3Optimism.sol';
import {AaveV3Polygon} from 'aave-address-book/AaveV3Polygon.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {IAccessControl} from 'openzeppelin-contracts/contracts/access/IAccessControl.sol';

import {CctpConstants} from 'src/bridges/cctp/CctpConstants.sol';
import {ICctpBridgeSteward} from 'src/bridges/cctp/interfaces/ICctpBridgeSteward.sol';

import {CctpBridgeStewardTestBase} from './CctpBridgeSteward.t.sol';

abstract contract BridgeTestBase is CctpBridgeStewardTestBase {
  function test_bridge_fast_owner() public {
    _bridge(owner, AMOUNT / 100, ICctpBridgeSteward.TransferSpeed.Fast);
  }

  function test_bridge_fast_guardian() public {
    _bridge(guardian, AMOUNT / 100, ICctpBridgeSteward.TransferSpeed.Fast);
  }

  function test_bridge_standard_owner() public {
    _bridge(owner, 0, ICctpBridgeSteward.TransferSpeed.Standard);
  }

  function test_bridge_standard_guardian() public {
    _bridge(guardian, 0, ICctpBridgeSteward.TransferSpeed.Standard);
  }
}

contract ArbitrumBridgeTest is BridgeTestBase {
  function setUp() public override {
    string memory rpcUrl = vm.envOr('RPC_ARBITRUM', string(''));
    vm.createSelectFork(rpcUrl, 459740700);

    usdc = IERC20(CctpConstants.ARBITRUM_USDC);
    collector = address(AaveV3Arbitrum.COLLECTOR);
    tokenMessenger = CctpConstants.ARBITRUM_TOKEN_MESSENGER;
    receiver = address(AaveV3Arbitrum.COLLECTOR);

    super.setUp();

    bytes32 fundsAdminRole = AaveV3Arbitrum.COLLECTOR.FUNDS_ADMIN_ROLE();
    vm.prank(AaveV3Arbitrum.ACL_ADMIN);
    IAccessControl(collector).grantRole(fundsAdminRole, address(bridge));
  }
}

contract BaseBridgeTest is BridgeTestBase {
  function setUp() public override {
    string memory rpcUrl = vm.envOr('RPC_BASE', string(''));
    vm.createSelectFork(rpcUrl, 45610300);

    usdc = IERC20(CctpConstants.BASE_USDC);
    collector = address(AaveV3Base.COLLECTOR);
    tokenMessenger = CctpConstants.BASE_TOKEN_MESSENGER;
    receiver = address(AaveV3Base.COLLECTOR);

    super.setUp();

    bytes32 fundsAdminRole = AaveV3Base.COLLECTOR.FUNDS_ADMIN_ROLE();
    vm.prank(AaveV3Base.ACL_ADMIN);
    IAccessControl(collector).grantRole(fundsAdminRole, address(bridge));
  }
}

contract OptimismBridgeTest is BridgeTestBase {
  function setUp() public override {
    string memory rpcUrl = vm.envOr('RPC_OPTIMISM', string(''));
    vm.createSelectFork(rpcUrl, 151205600);

    usdc = IERC20(CctpConstants.OPTIMISM_USDC);
    collector = address(AaveV3Optimism.COLLECTOR);
    tokenMessenger = CctpConstants.OPTIMISM_TOKEN_MESSENGER;
    receiver = address(AaveV3Optimism.COLLECTOR);

    super.setUp();

    bytes32 fundsAdminRole = AaveV3Optimism.COLLECTOR.FUNDS_ADMIN_ROLE();
    vm.prank(AaveV3Optimism.ACL_ADMIN);
    IAccessControl(collector).grantRole(fundsAdminRole, address(bridge));
  }
}

contract PolygonBridgeTest is BridgeTestBase {
  function setUp() public override {
    string memory rpcUrl = vm.envOr('RPC_POLYGON', string(''));
    vm.createSelectFork(rpcUrl, 86445000);

    usdc = IERC20(CctpConstants.POLYGON_USDC);
    collector = address(AaveV3Polygon.COLLECTOR);
    tokenMessenger = CctpConstants.POLYGON_TOKEN_MESSENGER;
    receiver = address(AaveV3Polygon.COLLECTOR);

    super.setUp();

    bytes32 fundsAdminRole = AaveV3Polygon.COLLECTOR.FUNDS_ADMIN_ROLE();
    vm.prank(AaveV3Polygon.ACL_ADMIN);
    IAccessControl(collector).grantRole(fundsAdminRole, address(bridge));
  }
}
