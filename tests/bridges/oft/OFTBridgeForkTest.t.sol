// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {GovernanceV3Ethereum} from "aave-address-book/GovernanceV3Ethereum.sol";
import {AaveV3Ethereum} from "aave-address-book/AaveV3Ethereum.sol";
import {AaveV3Arbitrum} from "aave-address-book/AaveV3Arbitrum.sol";
import {IWithGuardian} from "solidity-utils/contracts/access-control/interfaces/IWithGuardian.sol";

import {OFTConstants} from "src/bridges/oft/OFTConstants.sol";
import {OFTBridgeSteward} from "src/bridges/oft/OFTBridgeSteward.sol";
import {IOFT} from "src/bridges/oft/interfaces/IOFT.sol";
import {IOFTBridgeSteward} from "src/bridges/oft/interfaces/IOFTBridgeSteward.sol";

/**
 * @title OFTBridgeForkTestBase
 * @notice Fork tests for USDT0 OFT bridge via LayerZero V2.
 * @dev OFTBridgeSteward bridges *to* Ethereum (DESTINATION_EID is fixed to mainnet),
 *      so end-to-end bridging is tested on the Arbitrum fork. The mainnet instance
 *      only exercises constructor/immutable, ownership, and rescue paths.
 */
contract OFTBridgeForkTestBase is Test {
  uint256 public constant LARGE_BRIDGE_AMOUNT = 10_000_000e6; // 10 million USDT

  uint256 public mainnetFork;
  uint256 public arbitrumFork;

  address public owner = makeAddr("owner");
  address public guardian = makeAddr("guardian");
  address public mainnetReceiver;

  OFTBridgeSteward public mainnetBridge;
  OFTBridgeSteward public arbitrumBridge;

  event Bridge(
    address indexed token, uint32 indexed dstEid, address indexed receiver, uint256 amount, uint256 minAmountLD
  );

  function setUp() public virtual {
    // Receiver value is irrelevant for non-bridging mainnet tests; pick any non-zero address.
    mainnetReceiver = address(AaveV3Arbitrum.COLLECTOR);

    arbitrumFork = vm.createSelectFork(vm.rpcUrl("mainnet"));

    mainnetBridge = new OFTBridgeSteward(
      OFTConstants.ETHEREUM_USDT0_OFT, owner, guardian, address(AaveV3Ethereum.COLLECTOR), mainnetReceiver
    );
  }
}

/// @notice Quote tests for Arbitrum -> Ethereum USDT bridging via USDT0 OFT.
contract QuoteArbitrumToEthereumTest is OFTBridgeForkTestBase {
  function setUp() public override {
    arbitrumFork = vm.createSelectFork(vm.rpcUrl("arbitrum"));

    arbitrumBridge = new OFTBridgeSteward(
      OFTConstants.ARBITRUM_USDT0_OFT,
      owner,
      guardian,
      address(AaveV3Arbitrum.COLLECTOR),
      address(AaveV3Ethereum.COLLECTOR)
    );
  }

  function test_quoteSendFee_arbitrumToEthereum() public view {
    uint256 fee = arbitrumBridge.quoteSendFee(LARGE_BRIDGE_AMOUNT, LARGE_BRIDGE_AMOUNT);
    assertGt(fee, 0, "Fee should be greater than 0");
  }

  function test_quoteAmountReceived_arbitrumToEthereum() public view {
    uint256 amountReceived = arbitrumBridge.quoteAmountReceived(LARGE_BRIDGE_AMOUNT);
    assertEq(amountReceived, LARGE_BRIDGE_AMOUNT, "OFT should have no slippage");
  }

  function test_quote_arbitrumToEthereum_10MillionUSDT() public view {
    uint256 expectedReceived = arbitrumBridge.quoteAmountReceived(LARGE_BRIDGE_AMOUNT);
    assertEq(expectedReceived, LARGE_BRIDGE_AMOUNT, "OFT should have no slippage");

    uint256 fee = arbitrumBridge.quoteSendFee(LARGE_BRIDGE_AMOUNT, LARGE_BRIDGE_AMOUNT);
    assertGt(fee, 0, "Fee should be greater than 0");
  }
}

/// @notice Tests for Arbitrum -> Ethereum USDT bridging via USDT0 OFT.
contract BridgeArbitrumToEthereumTest is OFTBridgeForkTestBase {
  function setUp() public override {
    arbitrumFork = vm.createSelectFork(vm.rpcUrl("arbitrum"));

    arbitrumBridge = new OFTBridgeSteward(
      OFTConstants.ARBITRUM_USDT0_OFT,
      owner,
      guardian,
      address(AaveV3Arbitrum.COLLECTOR),
      address(AaveV3Ethereum.COLLECTOR)
    );

    bytes32 fundsAdminRole = AaveV3Arbitrum.COLLECTOR.FUNDS_ADMIN_ROLE();
    vm.prank(AaveV3Arbitrum.ACL_ADMIN);
    IAccessControl(address(AaveV3Arbitrum.COLLECTOR)).grantRole(fundsAdminRole, address(arbitrumBridge));
  }

  function test_bridge_arbitrumToEthereum_10MillionUSDT() public {
    address ethReceiver = address(AaveV3Ethereum.COLLECTOR);

    deal(OFTConstants.ARBITRUM_USDT, address(AaveV3Arbitrum.COLLECTOR), LARGE_BRIDGE_AMOUNT);
    assertEq(
      IERC20(OFTConstants.ARBITRUM_USDT).balanceOf(address(AaveV3Arbitrum.COLLECTOR)),
      LARGE_BRIDGE_AMOUNT,
      "Collector should have USDT"
    );

    uint256 expectedReceived = arbitrumBridge.quoteAmountReceived(LARGE_BRIDGE_AMOUNT);
    assertEq(expectedReceived, LARGE_BRIDGE_AMOUNT, "OFT should have no slippage");

    uint256 fee = arbitrumBridge.quoteSendFee(LARGE_BRIDGE_AMOUNT, LARGE_BRIDGE_AMOUNT);
    vm.deal(address(arbitrumBridge), fee + 1 ether);
    uint256 totalSupplyBefore = IERC20(OFTConstants.ARBITRUM_USDT).totalSupply();

    vm.expectEmit(true, true, true, true, address(arbitrumBridge));
    emit Bridge(
      OFTConstants.ARBITRUM_USDT, OFTConstants.ETHEREUM_EID, ethReceiver, LARGE_BRIDGE_AMOUNT, LARGE_BRIDGE_AMOUNT
    );

    vm.prank(owner);
    arbitrumBridge.bridge(LARGE_BRIDGE_AMOUNT, LARGE_BRIDGE_AMOUNT, fee);

    assertEq(
      IERC20(OFTConstants.ARBITRUM_USDT).balanceOf(address(AaveV3Arbitrum.COLLECTOR)),
      0,
      "Collector should have 0 USDT after bridging"
    );
    assertEq(
      IERC20(OFTConstants.ARBITRUM_USDT).balanceOf(address(arbitrumBridge)),
      0,
      "Bridge should have 0 USDT after bridging"
    );
    assertEq(
      IERC20(OFTConstants.ARBITRUM_USDT).totalSupply(),
      totalSupplyBefore - LARGE_BRIDGE_AMOUNT,
      "USDT should be burned on Arbitrum"
    );
    assertEq(
      IERC20(OFTConstants.ARBITRUM_USDT).allowance(address(arbitrumBridge), OFTConstants.ARBITRUM_USDT0_OFT),
      0,
      "Allowance between bridge and OFT should be 0"
    );
  }
}

contract RescueTokenTest is OFTBridgeForkTestBase {
  function test_rescueToken() public {
    uint256 amount = 1_000_000e6;
    deal(OFTConstants.ETHEREUM_USDT, address(mainnetBridge), amount);

    uint256 collectorBalanceBefore = IERC20(OFTConstants.ETHEREUM_USDT).balanceOf(address(AaveV3Ethereum.COLLECTOR));

    vm.prank(owner);
    mainnetBridge.rescueToken(OFTConstants.ETHEREUM_USDT);

    assertEq(
      IERC20(OFTConstants.ETHEREUM_USDT).balanceOf(address(AaveV3Ethereum.COLLECTOR)),
      collectorBalanceBefore + amount,
      "Collector should receive tokens"
    );
    assertEq(IERC20(OFTConstants.ETHEREUM_USDT).balanceOf(address(mainnetBridge)), 0, "Bridge should have 0 balance");
  }
}

/// @notice Tests for constructor and immutable values.
contract ConstructorAndImmutablesTest is OFTBridgeForkTestBase {
  function test_constructor_setsImmutables() public view {
    assertEq(mainnetBridge.OFT_USDT(), OFTConstants.ETHEREUM_USDT0_OFT, "OFT_USDT should be set correctly");
    assertEq(mainnetBridge.USDT(), OFTConstants.ETHEREUM_USDT, "USDT should be set correctly");
    assertEq(mainnetBridge.owner(), owner, "Owner should be set correctly");
    assertEq(mainnetBridge.guardian(), guardian, "Guardian should be set correctly");
    assertEq(mainnetBridge.COLLECTOR(), address(AaveV3Ethereum.COLLECTOR), "Collector should be set correctly");
    assertEq(mainnetBridge.RECEIVER(), mainnetReceiver, "Receiver should be set correctly");
  }

  function test_constructor_arbitrumBridge() public {
    arbitrumFork = vm.createSelectFork(vm.rpcUrl("arbitrum"));

    arbitrumBridge = new OFTBridgeSteward(
      OFTConstants.ARBITRUM_USDT0_OFT,
      owner,
      guardian,
      address(AaveV3Arbitrum.COLLECTOR),
      address(AaveV3Ethereum.COLLECTOR)
    );

    assertEq(arbitrumBridge.OFT_USDT(), OFTConstants.ARBITRUM_USDT0_OFT, "OFT_USDT should be set correctly");
    assertEq(arbitrumBridge.USDT(), OFTConstants.ARBITRUM_USDT, "USDT should be set correctly");
    assertEq(arbitrumBridge.owner(), owner, "Owner should be set correctly");
    assertEq(arbitrumBridge.guardian(), guardian, "Guardian should be set correctly");
    assertEq(arbitrumBridge.COLLECTOR(), address(AaveV3Arbitrum.COLLECTOR), "Collector should be set correctly");
    assertEq(arbitrumBridge.RECEIVER(), address(AaveV3Ethereum.COLLECTOR), "Receiver should be set correctly");
  }

  function test_constructor_revertsIf_zeroGuardian() public {
    vm.expectRevert(IOFTBridgeSteward.InvalidZeroAddress.selector);
    new OFTBridgeSteward(
      OFTConstants.ETHEREUM_USDT0_OFT, owner, address(0), address(AaveV3Ethereum.COLLECTOR), mainnetReceiver
    );
  }

  function test_constructor_revertsIf_zeroCollector() public {
    vm.expectRevert(IOFTBridgeSteward.InvalidZeroAddress.selector);
    new OFTBridgeSteward(OFTConstants.ETHEREUM_USDT0_OFT, owner, guardian, address(0), mainnetReceiver);
  }

  function test_constructor_revertsIf_zeroOft() public {
    vm.expectRevert(IOFTBridgeSteward.InvalidZeroAddress.selector);
    new OFTBridgeSteward(address(0), owner, guardian, address(AaveV3Ethereum.COLLECTOR), mainnetReceiver);
  }

  function test_constructor_revertsIf_zeroReceiver() public {
    vm.expectRevert(IOFTBridgeSteward.InvalidZeroAddress.selector);
    new OFTBridgeSteward(
      OFTConstants.ETHEREUM_USDT0_OFT, owner, guardian, address(AaveV3Ethereum.COLLECTOR), address(0)
    );
  }
}

/// @notice Tests for receive function and native token handling.
contract ReceiveFunctionTest is OFTBridgeForkTestBase {
  function test_receive_acceptsNativeTokens() public {
    uint256 balanceBefore = address(mainnetBridge).balance;

    address sender = makeAddr("sender");
    vm.deal(sender, 10 ether);

    vm.prank(sender);
    (bool success,) = address(mainnetBridge).call{value: 1 ether}("");

    assertTrue(success, "Should accept native tokens");
    assertEq(address(mainnetBridge).balance, balanceBefore + 1 ether, "Balance should increase");
  }
}

/// @notice Tests for rescue functionality.
contract RescuableTest is OFTBridgeForkTestBase {
  function test_maxRescue_returnsBridgeBalance() public {
    uint256 amount = 2_500e6;
    deal(OFTConstants.ETHEREUM_USDT, address(mainnetBridge), amount);

    assertEq(
      mainnetBridge.maxRescue(OFTConstants.ETHEREUM_USDT), amount, "maxRescue should return bridge token balance"
    );
  }

  function test_rescueToken_revertsIf_notOwnerOrGuardian() public {
    address notOwner = makeAddr("not-owner");
    uint256 amount = 1_000e6;
    deal(OFTConstants.ETHEREUM_USDT, address(mainnetBridge), amount);

    vm.prank(notOwner);
    vm.expectRevert(abi.encodeWithSelector(IWithGuardian.OnlyGuardianOrOwnerInvalidCaller.selector, notOwner));
    mainnetBridge.rescueToken(OFTConstants.ETHEREUM_USDT);
  }

  function test_rescueEth() public {
    uint256 ethAmount = 5 ether;
    vm.deal(address(mainnetBridge), ethAmount);

    uint256 collectorBalanceBefore = address(AaveV3Ethereum.COLLECTOR).balance;

    vm.prank(owner);
    mainnetBridge.rescueEth();

    assertEq(
      address(AaveV3Ethereum.COLLECTOR).balance, collectorBalanceBefore + ethAmount, "Collector should receive ETH"
    );
    assertEq(address(mainnetBridge).balance, 0, "Bridge should have 0 ETH balance");
  }
}
