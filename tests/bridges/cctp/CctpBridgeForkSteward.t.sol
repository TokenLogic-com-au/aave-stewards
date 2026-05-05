// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {AaveV3Arbitrum} from 'aave-address-book/AaveV3Arbitrum.sol';
import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {IAccessControl} from 'openzeppelin-contracts/contracts/access/IAccessControl.sol';
import {ERC20Mock} from 'openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {IWithGuardian} from 'solidity-utils/contracts/access-control/interfaces/IWithGuardian.sol';

import {CctpBridgeSteward} from 'src/bridges/cctp/CctpBridgeSteward.sol';
import {ICctpBridgeSteward} from 'src/bridges/cctp/interfaces/ICctpBridgeSteward.sol';
import {ITokenMessengerV2} from 'src/bridges/cctp/interfaces/ITokenMessengerV2.sol';
import {IMessageTransmitterV2} from 'src/bridges/cctp/interfaces/IMessageTransmitterV2.sol';
import {CctpConstants} from 'src/bridges/cctp/CctpConstants.sol';

contract CctpBridgeStewardForkTestBase is Test {
  CctpBridgeSteward public bridge;
  IERC20 public usdc = new ERC20Mock();
  address public tokenMessenger = makeAddr('tokenMessenger');
  address public owner = makeAddr('owner');
  address public guardian = makeAddr('guardian');
  address public collector = address(AaveV3Arbitrum.COLLECTOR);
  address public receiver = address(AaveV3Ethereum.COLLECTOR);
  address public alice = makeAddr('alice');

  uint256 public constant AMOUNT = 10_000e6; // 10k USDC

  function _deployBridge() internal returns (CctpBridgeSteward) {
    return
      new CctpBridgeSteward(tokenMessenger, address(usdc), owner, guardian, collector, receiver);
  }

  function _addressToBytes32(address addr) internal pure returns (bytes32) {
    return bytes32(uint256(uint160(addr)));
  }

  function _fundCollector(uint256 amount) internal {
    deal(address(usdc), collector, amount);
  }

  function setUp() public virtual {
    try vm.activeFork() returns (uint256) {
      // If we are on a fork, continue.
    } catch {
      // If not, mock the necessary calls to deploy the bridge correctly.
      address localMessageTransmitter = makeAddr('localMessageTransmitter');
      vm.mockCall(
        tokenMessenger,
        abi.encodeCall(ITokenMessengerV2(tokenMessenger).localMessageTransmitter, ()),
        abi.encode(localMessageTransmitter)
      );
      vm.mockCall(
        localMessageTransmitter,
        abi.encodeCall(IMessageTransmitterV2(localMessageTransmitter).localDomain, ()),
        abi.encode(CctpConstants.ARBITRUM_DOMAIN)
      );
    }

    bridge = _deployBridge();

    _fundCollector(AMOUNT);
  }

  function _bridge(uint256 maxFee, ICctpBridgeSteward.TransferSpeed speed) internal {
    uint256 collectorBalanceBefore = usdc.balanceOf(collector);

    vm.expectEmit();
    emit ICctpBridgeSteward.Bridge(
      address(usdc),
      CctpConstants.ETHEREUM_DOMAIN,
      receiver,
      AMOUNT,
      speed
    );

    vm.prank(owner);
    bridge.bridge(AMOUNT, maxFee, speed);

    assertEq(usdc.balanceOf(address(bridge)), 0, 'Bridge should have no USDC left');
    assertEq(
      usdc.balanceOf(collector),
      collectorBalanceBefore - AMOUNT,
      'Collector should transfer USDC'
    );
  }
}

contract BridgeFailuresTest is CctpBridgeStewardForkTestBase {
  function test_revertsIf_callerNotOwnerOrGuardian() public {
    vm.startPrank(alice);
    vm.expectRevert(
      abi.encodeWithSelector(IWithGuardian.OnlyGuardianOrOwnerInvalidCaller.selector, alice)
    );
    bridge.bridge(
      AMOUNT,
      0,
      ICctpBridgeSteward.TransferSpeed.Fast
    );
    vm.stopPrank();
  }

  function test_revertsIf_zeroAmount() public {
    vm.startPrank(owner);
    vm.expectRevert(ICctpBridgeSteward.InvalidZeroAmount.selector);
    bridge.bridge(
      0,
      0,
      ICctpBridgeSteward.TransferSpeed.Fast
    );
    vm.stopPrank();
  }
}

contract BridgeTest is CctpBridgeStewardForkTestBase {
  function setUp() public override {
    string memory rpcUrl = vm.envOr('RPC_ARBITRUM', string(''));
    vm.createSelectFork(rpcUrl);

    usdc = IERC20(CctpConstants.ARBITRUM_USDC);
    collector = address(AaveV3Arbitrum.COLLECTOR);
    tokenMessenger = CctpConstants.ARBITRUM_TOKEN_MESSENGER;
    receiver = address(AaveV3Arbitrum.COLLECTOR);

    super.setUp();

    bytes32 fundsAdminRole = AaveV3Arbitrum.COLLECTOR.FUNDS_ADMIN_ROLE();
    vm.prank(AaveV3Arbitrum.ACL_ADMIN);
    IAccessControl(collector).grantRole(fundsAdminRole, address(bridge));
  }

  function test_bridge_fast() public {
    _bridge(
      AMOUNT / 100,
      ICctpBridgeSteward.TransferSpeed.Fast
    );
  }

  function test_bridge_fast_guardian() public {
    uint256 collectorBalanceBefore = usdc.balanceOf(collector);

    vm.expectEmit();
    emit ICctpBridgeSteward.Bridge(
      address(usdc),
      CctpConstants.ETHEREUM_DOMAIN,
      receiver,
      AMOUNT,
      ICctpBridgeSteward.TransferSpeed.Fast
    );

    vm.prank(guardian);
    bridge.bridge(
      AMOUNT,
      AMOUNT / 100,
      ICctpBridgeSteward.TransferSpeed.Fast
    );

    assertEq(usdc.balanceOf(address(bridge)), 0, 'Bridge should have no USDC left');
    assertEq(
      usdc.balanceOf(collector),
      collectorBalanceBefore - AMOUNT,
      'Collector should transfer USDC'
    );
  }

  function test_bridge_standard() public {
    _bridge(
      0,
      ICctpBridgeSteward.TransferSpeed.Standard
    );
  }
}

contract ConstructorTest is CctpBridgeStewardForkTestBase {
  function test_revertsIf_constructorTokenMessengerZero() public {
    vm.expectRevert(ICctpBridgeSteward.InvalidZeroAddress.selector);
    new CctpBridgeSteward(
      address(0),
      CctpConstants.ETHEREUM_USDC,
      owner,
      guardian,
      collector,
      receiver
    );
  }

  function test_revertsIf_constructorUsdcZero() public {
    vm.expectRevert(ICctpBridgeSteward.InvalidZeroAddress.selector);
    new CctpBridgeSteward(
      CctpConstants.ETHEREUM_TOKEN_MESSENGER,
      address(0),
      owner,
      guardian,
      collector,
      receiver
    );
  }

  function test_revertsIf_constructorGuardianZero() public {
    vm.expectRevert(ICctpBridgeSteward.InvalidZeroAddress.selector);
    new CctpBridgeSteward(
      CctpConstants.ETHEREUM_TOKEN_MESSENGER,
      CctpConstants.ETHEREUM_USDC,
      owner,
      address(0),
      collector,
      receiver
    );
  }

  function test_revertsIf_constructorCollectorZero() public {
    vm.expectRevert(ICctpBridgeSteward.InvalidZeroAddress.selector);
    new CctpBridgeSteward(
      CctpConstants.ETHEREUM_TOKEN_MESSENGER,
      CctpConstants.ETHEREUM_USDC,
      owner,
      guardian,
      address(0),
      receiver
    );
  }

  function test_revertsIf_constructorReceiverZero() public {
    vm.expectRevert(ICctpBridgeSteward.InvalidZeroAddress.selector);
    new CctpBridgeSteward(
      CctpConstants.ETHEREUM_TOKEN_MESSENGER,
      CctpConstants.ETHEREUM_USDC,
      owner,
      guardian,
      collector,
      address(0)
    );
  }
}

contract RescuableTest is CctpBridgeStewardForkTestBase {
  function test_rescueToken_guardian() public {
    deal(address(usdc), address(bridge), AMOUNT);

    uint256 collectorBalanceBefore = usdc.balanceOf(collector);

    vm.prank(guardian);
    bridge.rescueToken(address(usdc));

    assertEq(usdc.balanceOf(address(bridge)), 0, 'Rescue bridge should have no USDC left');
    assertEq(
      usdc.balanceOf(collector),
      collectorBalanceBefore + AMOUNT,
      'Collector should receive rescued USDC'
    );
  }

  function test_sendEthToBridge_reverts() public {
    vm.deal(address(this), 1 ether);
    vm.expectRevert(ICctpBridgeSteward.CannotReceiveEther.selector);
    payable(bridge).transfer(1 ether);
  }

  function test_rescueEth_owner() public {
    uint256 rescueAmount = 1 ether;
    // Bridge cannot receive ether through regular transfers, so we use vm.deal directly.
    vm.deal(address(bridge), rescueAmount);
    assertEq(address(bridge).balance, rescueAmount, 'Bridge should have ETH to rescue');

    uint256 collectorBalanceBefore = collector.balance;

    vm.prank(owner);
    bridge.rescueEth();

    assertEq(address(bridge).balance, 0, 'Bridge should have no ETH left');
    assertEq(
      collector.balance,
      collectorBalanceBefore + rescueAmount,
      'Collector should receive rescued ETH'
    );
  }

  function test_maxRescue_returnsFullBalance() public {
    deal(address(usdc), address(bridge), AMOUNT);

    assertEq(bridge.maxRescue(address(usdc)), AMOUNT);
  }
}
