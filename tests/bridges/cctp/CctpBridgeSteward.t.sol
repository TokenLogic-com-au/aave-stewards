// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {AaveV3Arbitrum} from "aave-address-book/AaveV3Arbitrum.sol";
import {AaveV3Ethereum} from "aave-address-book/AaveV3Ethereum.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {IWithGuardian} from "solidity-utils/contracts/access-control/interfaces/IWithGuardian.sol";

import {CctpBridgeSteward} from "src/bridges/cctp/CctpBridgeSteward.sol";
import {ICctpBridgeSteward} from "src/bridges/cctp/interfaces/ICctpBridgeSteward.sol";
import {ITokenMessengerV2} from "src/bridges/cctp/interfaces/ITokenMessengerV2.sol";
import {IMessageTransmitterV2} from "src/bridges/cctp/interfaces/IMessageTransmitterV2.sol";
import {CctpConstants} from "src/bridges/cctp/CctpConstants.sol";

contract CctpBridgeStewardTestBase is Test {
  CctpBridgeSteward public bridge;
  IERC20 public usdc = IERC20(CctpConstants.ARBITRUM_USDC);
  address public tokenMessenger = CctpConstants.ARBITRUM_TOKEN_MESSENGER;
  address public collector = address(AaveV3Arbitrum.COLLECTOR);
  address public receiver = address(AaveV3Ethereum.COLLECTOR);
  address public owner = makeAddr("owner");
  address public guardian = makeAddr("guardian");
  address public alice = makeAddr("alice");

  uint256 public constant AMOUNT = 10_000e6; // 10k USDC

  function _deployBridge() internal returns (CctpBridgeSteward) {
    return new CctpBridgeSteward(tokenMessenger, address(usdc), owner, guardian, collector);
  }

  function _addressToBytes32(address addr) internal pure returns (bytes32) {
    return bytes32(uint256(uint160(addr)));
  }

  function _fundCollector(uint256 amount) internal {
    deal(address(usdc), collector, amount);
  }

  function setUp() public virtual {
    string memory rpcUrl = vm.envOr("RPC_ARBITRUM", string(""));
    vm.createSelectFork(rpcUrl, 459740700);
    bridge = _deployBridge();

    _fundCollector(AMOUNT);

    bytes32 fundsAdminRole = AaveV3Arbitrum.COLLECTOR.FUNDS_ADMIN_ROLE();
    vm.prank(AaveV3Arbitrum.ACL_ADMIN);
    IAccessControl(collector).grantRole(fundsAdminRole, address(bridge));
  }
}

contract BridgeFailuresTest is CctpBridgeStewardTestBase {
  function test_revertsIf_callerNotOwnerOrGuardian() public {
    vm.prank(alice);
    vm.expectRevert(abi.encodeWithSelector(IWithGuardian.OnlyGuardianOrOwnerInvalidCaller.selector, alice));
    bridge.bridge(AMOUNT, 0, ICctpBridgeSteward.TransferSpeed.Fast);
  }

  function test_revertsIf_zeroAmount() public {
    vm.prank(owner);
    vm.expectRevert(ICctpBridgeSteward.InvalidZeroAmount.selector);
    bridge.bridge(0, 0, ICctpBridgeSteward.TransferSpeed.Fast);
  }

  function test_revertsIf_maxFeeGteAmount() public {
    uint256 maxFee = AMOUNT;
    vm.prank(owner);
    vm.expectRevert(abi.encodeWithSelector(ICctpBridgeSteward.InvalidMaxFee.selector, maxFee, AMOUNT));
    bridge.bridge(AMOUNT, maxFee, ICctpBridgeSteward.TransferSpeed.Fast);
  }
}

contract ConstructorTest is CctpBridgeStewardTestBase {
  function test_immutables() public view {
    assertEq(bridge.TOKEN_MESSENGER(), tokenMessenger, "TOKEN_MESSENGER mismatch");
    assertEq(bridge.USDC(), address(usdc), "USDC mismatch");
    assertEq(bridge.COLLECTOR(), collector, "COLLECTOR mismatch");
    assertEq(bridge.MAINNET_COLLECTOR(), receiver, "MAINNET_COLLECTOR mismatch");
    assertEq(bridge.LOCAL_DOMAIN(), CctpConstants.ARBITRUM_DOMAIN, "LOCAL_DOMAIN mismatch");
    assertEq(bridge.DESTINATION_DOMAIN(), CctpConstants.ETHEREUM_DOMAIN, "DESTINATION_DOMAIN mismatch");
    assertEq(bridge.owner(), owner, "owner mismatch");
    assertEq(bridge.guardian(), guardian, "guardian mismatch");
  }

  function test_revertsIf_localDomainEqualsDestination() public {
    address localMessageTransmitter = makeAddr("localMessageTransmitter");
    vm.mockCall(
      tokenMessenger, abi.encodeCall(ITokenMessengerV2.localMessageTransmitter, ()), abi.encode(localMessageTransmitter)
    );
    vm.mockCall(
      localMessageTransmitter,
      abi.encodeCall(IMessageTransmitterV2.localDomain, ()),
      abi.encode(CctpConstants.ETHEREUM_DOMAIN)
    );

    vm.expectRevert(ICctpBridgeSteward.InvalidLocalDomain.selector);
    new CctpBridgeSteward(tokenMessenger, address(usdc), owner, guardian, collector);
  }

  function test_revertsIf_constructorTokenMessengerZero() public {
    vm.expectRevert(ICctpBridgeSteward.InvalidZeroAddress.selector);
    new CctpBridgeSteward(address(0), CctpConstants.ETHEREUM_USDC, owner, guardian, collector);
  }

  function test_revertsIf_constructorUsdcZero() public {
    vm.expectRevert(ICctpBridgeSteward.InvalidZeroAddress.selector);
    new CctpBridgeSteward(CctpConstants.ETHEREUM_TOKEN_MESSENGER, address(0), owner, guardian, collector);
  }

  function test_revertsIf_constructorOwnerZero() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
    new CctpBridgeSteward(
      CctpConstants.ETHEREUM_TOKEN_MESSENGER, CctpConstants.ETHEREUM_USDC, address(0), guardian, collector
    );
  }

  function test_revertsIf_constructorGuardianZero() public {
    vm.expectRevert(ICctpBridgeSteward.InvalidZeroAddress.selector);
    new CctpBridgeSteward(
      CctpConstants.ETHEREUM_TOKEN_MESSENGER, CctpConstants.ETHEREUM_USDC, owner, address(0), collector
    );
  }

  function test_revertsIf_constructorCollectorZero() public {
    vm.expectRevert(ICctpBridgeSteward.InvalidZeroAddress.selector);
    new CctpBridgeSteward(
      CctpConstants.ETHEREUM_TOKEN_MESSENGER, CctpConstants.ETHEREUM_USDC, owner, guardian, address(0)
    );
  }
}

contract BridgeTest is CctpBridgeStewardTestBase {
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

  function _bridge(address caller, uint256 maxFee, ICctpBridgeSteward.TransferSpeed speed) internal {
    uint256 collectorBalanceBefore = usdc.balanceOf(collector);

    vm.expectEmit();
    emit ICctpBridgeSteward.Bridge(address(usdc), CctpConstants.ETHEREUM_DOMAIN, receiver, AMOUNT, speed);

    vm.prank(caller);
    bridge.bridge(AMOUNT, maxFee, speed);

    assertEq(usdc.balanceOf(address(bridge)), 0, "Bridge should have no USDC left");
    assertEq(usdc.balanceOf(collector), collectorBalanceBefore - AMOUNT, "Collector should transfer USDC");
    assertEq(
      usdc.allowance(address(bridge), tokenMessenger), 0, "Bridge should have no USDC allowance for TokenMessenger"
    );
  }
}

contract RescuableTest is CctpBridgeStewardTestBase {
  function test_rescueToken_guardian() public {
    deal(address(usdc), address(bridge), AMOUNT);

    uint256 collectorBalanceBefore = usdc.balanceOf(collector);

    vm.prank(guardian);
    bridge.rescueToken(address(usdc));

    assertEq(usdc.balanceOf(address(bridge)), 0, "Rescue bridge should have no USDC left");
    assertEq(usdc.balanceOf(collector), collectorBalanceBefore + AMOUNT, "Collector should receive rescued USDC");
  }

  function test_rescueToken_owner() public {
    deal(address(usdc), address(bridge), AMOUNT);

    uint256 collectorBalanceBefore = usdc.balanceOf(collector);

    vm.prank(owner);
    bridge.rescueToken(address(usdc));

    assertEq(usdc.balanceOf(address(bridge)), 0, "Rescue bridge should have no USDC left");
    assertEq(usdc.balanceOf(collector), collectorBalanceBefore + AMOUNT, "Collector should receive rescued USDC");
  }

  function test_rescueToken_nonUsdc() public {
    IERC20 other = new ERC20Mock();
    deal(address(other), address(bridge), AMOUNT);

    vm.prank(owner);
    bridge.rescueToken(address(other));

    assertEq(other.balanceOf(address(bridge)), 0, "Bridge should have no token left");
    assertEq(other.balanceOf(collector), AMOUNT, "Collector should receive rescued token");
  }

  function test_rescueToken_revertsIf_notOwnerOrGuardian() public {
    deal(address(usdc), address(bridge), AMOUNT);

    vm.prank(alice);
    vm.expectRevert(abi.encodeWithSelector(IWithGuardian.OnlyGuardianOrOwnerInvalidCaller.selector, alice));
    bridge.rescueToken(address(usdc));
  }

  function test_rescueEth_owner() public {
    uint256 rescueAmount = 1 ether;
    vm.deal(address(bridge), rescueAmount);
    assertEq(address(bridge).balance, rescueAmount, "Bridge should have ETH to rescue");

    uint256 collectorBalanceBefore = collector.balance;

    vm.prank(owner);
    bridge.rescueEth();

    assertEq(address(bridge).balance, 0, "Bridge should have no ETH left");
    assertEq(collector.balance, collectorBalanceBefore + rescueAmount, "Collector should receive rescued ETH");
  }

  function test_rescueEth_guardian() public {
    uint256 rescueAmount = 1 ether;
    vm.deal(address(bridge), rescueAmount);

    uint256 collectorBalanceBefore = collector.balance;

    vm.prank(guardian);
    bridge.rescueEth();

    assertEq(address(bridge).balance, 0, "Bridge should have no ETH left");
    assertEq(collector.balance, collectorBalanceBefore + rescueAmount, "Collector should receive rescued ETH");
  }

  function test_rescueEth_revertsIf_notOwnerOrGuardian() public {
    // Bridge cannot receive ether through regular transfers, so we use vm.deal directly.
    vm.deal(address(bridge), 1 ether);

    vm.prank(alice);
    vm.expectRevert(abi.encodeWithSelector(IWithGuardian.OnlyGuardianOrOwnerInvalidCaller.selector, alice));
    bridge.rescueEth();
  }

  function test_maxRescue_returnsFullBalance() public {
    deal(address(usdc), address(bridge), AMOUNT);

    assertEq(bridge.maxRescue(address(usdc)), AMOUNT);
  }
}
