// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/StdStorage.sol";

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {AaveV3Ethereum, AaveV3EthereumAssets} from "aave-address-book/AaveV3Ethereum.sol";
import {GovernanceV3Ethereum} from "aave-address-book/GovernanceV3Ethereum.sol";
import {IRescuable} from "solidity-utils/contracts/utils/interfaces/IRescuable.sol";
import {IWithGuardian} from "solidity-utils/contracts/access-control/interfaces/IWithGuardian.sol";

import {StakedTokenWithdrawerSteward, IStakedTokenWithdrawerSteward, IStMatic, IWithdrawalQueueERC721} from "src/asset-manager/stmatic-withdrawer/StakedTokenWithdrawerSteward.sol";

interface IStakeManager {
    function setCurrentEpoch(uint256 _currentEpoch) external;
}

/// @dev forge test --match-path=tests/asset-manager/stmatic-withdrawer/StakedTokenWithdrawerStewardTest.t.sol -vv
contract StakedTokenWithdrawerStewardTest is Test {
    address public constant OWNER = GovernanceV3Ethereum.EXECUTOR_LVL_1;
    /// https://etherscan.io/address/0x22740deBa78d5a0c24C58C740e3715ec29de1bFa
    address public constant GUARDIAN =
        0x22740deBa78d5a0c24C58C740e3715ec29de1bFa;
    address public constant COLLECTOR = address(AaveV3Ethereum.COLLECTOR);
    address public constant WETH = AaveV3EthereumAssets.WETH_UNDERLYING;
    address public constant WSTETH = AaveV3EthereumAssets.wstETH_UNDERLYING;

    address public ST_MATIC;
    address public UNSTETH;

    StakedTokenWithdrawerSteward public withdrawer;

    event StartedStMaticWithdrawal(
        address indexed token,
        uint256 amount,
        uint256 indexed tokenId
    );
    event StartedWstEthWithdrawal(
        address indexed token,
        uint256[] amounts,
        uint256 indexed tokenId
    );
    event FinalizedWithdrawal(
        address indexed token,
        uint256 amount,
        uint256 indexed tokenId
    );

    function setUp() public virtual {
        vm.createSelectFork("mainnet", 21867043);
        withdrawer = new StakedTokenWithdrawerSteward();
        ST_MATIC = withdrawer.ST_MATIC();
        UNSTETH = withdrawer.WSTETH_WITHDRAWAL_QUEUE();
    }

    function _unpauseStMATIC() internal {
        bytes32 UNPAUSE_ROLE = IStMatic(ST_MATIC).UNPAUSE_ROLE();
        address dao = IStMatic(ST_MATIC).dao();

        vm.startPrank(dao);
        IAccessControl(ST_MATIC).grantRole(UNPAUSE_ROLE, dao);
        IStMatic(ST_MATIC).unpause();
        vm.stopPrank();
    }

    function _increaseEpoch(uint256 epoch) internal {
        IStakeManager stakeManager = IStakeManager(
            IStMatic(ST_MATIC).stakeManager()
        );

        // 0x6e7a5820baD6cebA8Ef5ea69c0C92EbbDAc9CE48: governance of stakeManager
        vm.startPrank(0x6e7a5820baD6cebA8Ef5ea69c0C92EbbDAc9CE48);
        stakeManager.setCurrentEpoch(epoch);

        vm.stopPrank();
    }
}

contract StMaticStartWithdrawTest is StakedTokenWithdrawerStewardTest {
    uint256 amount = 1_000e18;

    function test_revertsIf_invalidCaller() public {
        deal(ST_MATIC, address(withdrawer), amount);

        vm.expectRevert(
            abi.encodeWithSelector(
                IWithGuardian.OnlyGuardianOrOwnerInvalidCaller.selector,
                address(this)
            )
        );
        withdrawer.startWithdrawStMatic(amount);
        vm.stopPrank();
    }

    function test_success() public {
        vm.startPrank(GUARDIAN);
        deal(ST_MATIC, address(withdrawer), amount);
        uint256 nextIndex = withdrawer.nextIndex();

        vm.expectEmit(true, true, false, true, address(withdrawer));
        emit StartedStMaticWithdrawal(ST_MATIC, amount, nextIndex);
        withdrawer.startWithdrawStMatic(amount);

        uint256 amountAfter = IERC20(ST_MATIC).balanceOf(address(withdrawer));

        assertEq(amountAfter, 0);

        vm.stopPrank();
    }
}

contract StMaticFinalizeWithdrawTest is StakedTokenWithdrawerStewardTest {
    uint256 amount = 1_000e18;
    uint256 tokenId = 4173; // dynamically calculated

    function setUp() public override {
        super.setUp();

        vm.startPrank(GUARDIAN);
        deal(ST_MATIC, address(withdrawer), amount);

        withdrawer.startWithdrawStMatic(amount);
        vm.stopPrank();
    }

    function test_revertsIf_EpochNotReached() public {
        vm.expectRevert("Not able to claim yet");
        withdrawer.finalizeWithdraw(0);
    }

    function test_success() public {
        uint256 requestEpoch;
        uint256 withdrawAmount;
        (, , requestEpoch, ) = IStMatic(ST_MATIC).token2WithdrawRequest(0);
        if (requestEpoch == 0) {
            IStMatic.RequestWithdraw[] memory requests = IStMatic(ST_MATIC)
                .getToken2WithdrawRequests(tokenId);
            requestEpoch = requests[0].requestEpoch;
            for (uint256 i = 0; i < requests.length; ++i) {
                withdrawAmount += requests[i].amount2WithdrawFromStMATIC;
            }
        }
        _increaseEpoch(requestEpoch + 1);

        uint256 amountBefore = IERC20(IStMatic(ST_MATIC).token()).balanceOf(
            COLLECTOR
        );

        vm.expectEmit(true, true, false, true, address(withdrawer));
        emit FinalizedWithdrawal(ST_MATIC, withdrawAmount, 0);
        withdrawer.finalizeWithdraw(0);

        uint256 amountAfter = IERC20(IStMatic(ST_MATIC).token()).balanceOf(
            COLLECTOR
        );
        uint256 nftCount = IERC721(IStMatic(ST_MATIC).poLidoNFT()).balanceOf(
            address(withdrawer)
        );

        assertEq(amountAfter, amountBefore + withdrawAmount);
        assertEq(nftCount, 0);
    }
}

contract WstEthStartWithdrawTest is StakedTokenWithdrawerStewardTest {
    uint256 amount = 100e18;

    function test_revertsIf_invalidCaller() public {
        vm.prank(OWNER);
        deal(WSTETH, address(withdrawer), amount);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        vm.expectRevert(
            abi.encodeWithSelector(
                IWithGuardian.OnlyGuardianOrOwnerInvalidCaller.selector,
                address(this)
            )
        );
        withdrawer.startWithdrawWstEth(amounts);
        vm.stopPrank();
    }

    function test_startWithdrawalOwner() public {
        uint256 stEthBalanceBefore = IERC20(WSTETH).balanceOf(
            address(withdrawer)
        );
        uint256 lidoNftBalanceBefore = IERC20(UNSTETH).balanceOf(
            address(withdrawer)
        );
        uint256 nextIndex = withdrawer.nextIndex();

        vm.startPrank(OWNER);
        deal(WSTETH, address(withdrawer), amount);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        vm.expectEmit(address(withdrawer));
        emit StartedWstEthWithdrawal(WSTETH, amounts, nextIndex);
        withdrawer.startWithdrawWstEth(amounts);
        vm.stopPrank();

        uint256 stEthBalanceAfter = IERC20(WSTETH).balanceOf(
            address(withdrawer)
        );
        uint256 lidoNftBalanceAfter = IERC20(UNSTETH).balanceOf(
            address(withdrawer)
        );

        assertEq(stEthBalanceAfter, stEthBalanceBefore);
        assertEq(lidoNftBalanceAfter, lidoNftBalanceBefore + 1);
    }

    function test_startWithdrawalGuardian() public {
        uint256 stEthBalanceBefore = IERC20(WSTETH).balanceOf(
            address(withdrawer)
        );
        uint256 lidoNftBalanceBefore = IERC20(UNSTETH).balanceOf(
            address(withdrawer)
        );
        uint256 nextIndex = withdrawer.nextIndex();

        vm.prank(OWNER);
        deal(WSTETH, address(withdrawer), amount);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        vm.expectEmit(address(withdrawer));
        emit StartedWstEthWithdrawal(WSTETH, amounts, nextIndex);
        vm.prank(GUARDIAN);
        withdrawer.startWithdrawWstEth(amounts);

        uint256 stEthBalanceAfter = IERC20(WSTETH).balanceOf(
            address(withdrawer)
        );
        uint256 lidoNftBalanceAfter = IERC20(UNSTETH).balanceOf(
            address(withdrawer)
        );

        assertEq(stEthBalanceAfter, stEthBalanceBefore);
        assertEq(lidoNftBalanceAfter, lidoNftBalanceBefore + 1);
    }
}

contract WstEthFinalizeWithdrawalTest is StakedTokenWithdrawerStewardTest {
    using stdStorage for StdStorage;

    /// at block #21867043 0xb9b...A93 already has a UNSTETH token representing a 999999999900 wei withdrawal
    address public constant UNSTETH_OWNER =
        0xb9b8F880dCF1bb34933fcDb375EEdE6252177A93;
    uint256 amount = 2e18;
    uint256 withdrawalAmount = 1173102309960;

    function setUp() public override {
        super.setUp();

        vm.startPrank(OWNER);
        /// transfer the unSTETH to withdrawer
        StakedTokenWithdrawerSteward(payable(UNSTETH_OWNER))
            .emergency721TokenTransfer(
                address(UNSTETH),
                address(withdrawer),
                46283
            );

        /// start an withdrawal to create the storage slot
        AaveV3Ethereum.COLLECTOR.transfer(
            address(WSTETH),
            address(withdrawer),
            amount
        );
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        withdrawer.startWithdrawWstEth(amounts);
        vm.stopPrank();

        /// override the storage slot to the requestId respective to the unSTETH NFT
        /// and the minCheckpointIndex
        uint256 key = 0;
        uint256 reqId = 46283;
        uint256 minIndex = 429;
        // Calculate the storage slot for requests[0].requestIds[0]
        uint256 requestsSlot = stdstore
            .target(address(withdrawer))
            .sig("requests(uint256)")
            .with_key(key)
            .find(); // Finds the storage slot for requests[0]

        // The requestIds array is at requestsSlot + 1 (since token occupies the first slot)
        uint256 requestIdsSlot = uint256(
            keccak256(abi.encode(requestsSlot + 1))
        );
        // The first element of the array is at requestIdsSlot
        uint256 elementSlot = requestIdsSlot + key;

        // Write the new value to requests[0].requestIds[0]
        vm.store(address(withdrawer), bytes32(elementSlot), bytes32(reqId));

        stdstore
            .target(address(withdrawer))
            .sig("minCheckpointIndex()")
            .checked_write(minIndex);
    }

    function test_finalizeWithdrawalGuardian() public {
        uint256 collectorBalanceBefore = IERC20(WETH).balanceOf(COLLECTOR);

        vm.deal(address(withdrawer), 0);

        vm.startPrank(GUARDIAN);
        vm.expectEmit(address(withdrawer));
        emit FinalizedWithdrawal(WSTETH, withdrawalAmount, 0);
        withdrawer.finalizeWithdraw(0);
        vm.stopPrank();

        uint256 collectorBalanceAfter = IERC20(WETH).balanceOf(COLLECTOR);

        assertEq(
            collectorBalanceAfter,
            collectorBalanceBefore + withdrawalAmount
        );
    }

    function test_finalizeWithdrawalOwner() public {
        uint256 collectorBalanceBefore = IERC20(WETH).balanceOf(COLLECTOR);

        vm.deal(address(withdrawer), 0);

        vm.startPrank(OWNER);
        vm.expectEmit(address(withdrawer));
        emit FinalizedWithdrawal(WSTETH, withdrawalAmount, 0);
        withdrawer.finalizeWithdraw(0);
        vm.stopPrank();

        uint256 collectorBalanceAfter = IERC20(WETH).balanceOf(COLLECTOR);

        assertEq(
            collectorBalanceAfter,
            collectorBalanceBefore + withdrawalAmount
        );
    }

    function test_finalizeWithdrawalWithExtraFunds() public {
        uint256 collectorBalanceBefore = IERC20(WETH).balanceOf(COLLECTOR);

        // /// send 1 wei to withdrawer
        vm.deal(address(withdrawer), 1);

        vm.startPrank(OWNER);
        vm.expectEmit(address(withdrawer));
        emit FinalizedWithdrawal(WSTETH, withdrawalAmount + 1, 0);
        withdrawer.finalizeWithdraw(0);
        vm.stopPrank();

        uint256 collectorBalanceAfter = IERC20(WETH).balanceOf(COLLECTOR);

        assertEq(
            collectorBalanceAfter,
            collectorBalanceBefore + withdrawalAmount + 1
        );
    }
}

contract TransferOwnership is StakedTokenWithdrawerStewardTest {
    function test_revertsIf_invalidCaller() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                address(this)
            )
        );
        withdrawer.transferOwnership(makeAddr("new-admin"));
    }

    function test_successful() public {
        address newAdmin = makeAddr("new-admin");
        vm.startPrank(OWNER);
        withdrawer.transferOwnership(newAdmin);
        vm.stopPrank();

        assertEq(newAdmin, withdrawer.owner());
    }
}

contract UpdateGuardian is StakedTokenWithdrawerStewardTest {
    function test_revertsIf_invalidCaller() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IWithGuardian.OnlyGuardianOrOwnerInvalidCaller.selector,
                address(this)
            )
        );
        withdrawer.updateGuardian(makeAddr("new-admin"));
    }

    function test_successful() public {
        address newManager = makeAddr("new-admin");
        vm.startPrank(OWNER);
        withdrawer.updateGuardian(newManager);
        vm.stopPrank();

        assertEq(newManager, withdrawer.guardian());
    }
}

contract EmergencyTokenTransfer is StakedTokenWithdrawerStewardTest {
    uint256 amount = 1_000e18;

    function test_successful() public {
        uint256 initialCollectorBalance = IERC20(ST_MATIC).balanceOf(COLLECTOR);
        deal(ST_MATIC, address(withdrawer), amount);
        vm.startPrank(OWNER);
        withdrawer.emergencyTokenTransfer(ST_MATIC, amount);
        vm.stopPrank();

        assertEq(
            IERC20(ST_MATIC).balanceOf(COLLECTOR),
            initialCollectorBalance + amount
        );
        assertEq(IERC20(ST_MATIC).balanceOf(address(withdrawer)), 0);
    }
}

contract Emergency721TokenTransfer is StakedTokenWithdrawerStewardTest {
    uint256 amount = 1_000e18;
    uint256 tokenId = 4173; // dynamically calculated
    IERC721 poLidoNFT;

    function setUp() public override {
        super.setUp();

        poLidoNFT = IERC721(IStMatic(ST_MATIC).poLidoNFT());

        vm.startPrank(GUARDIAN);
        deal(ST_MATIC, address(withdrawer), amount);

        withdrawer.startWithdrawStMatic(amount);
        vm.stopPrank();
    }

    function test_revertsIf_invalidCaller() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IWithGuardian.OnlyGuardianOrOwnerInvalidCaller.selector,
                address(this)
            )
        );
        withdrawer.emergency721TokenTransfer(
            address(poLidoNFT),
            COLLECTOR,
            tokenId
        );
    }

    function test_successful_governanceCaller() public {
        uint256 lidoNftBalanceBefore = poLidoNFT.balanceOf(address(withdrawer));
        vm.startPrank(OWNER);
        withdrawer.emergency721TokenTransfer(
            address(poLidoNFT),
            COLLECTOR,
            tokenId
        );
        vm.stopPrank();

        uint256 lidoNftBalanceAfter = poLidoNFT.balanceOf(address(withdrawer));

        assertEq(poLidoNFT.balanceOf(COLLECTOR), 1);
        assertEq(lidoNftBalanceAfter, lidoNftBalanceBefore - 1);
    }
}
