// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {StakedTokenWithdrawerSteward, IStakedTokenWithdrawerSteward, IStMatic} from "src/asset-manager/stmatic-withdrawer/StakedTokenWithdrawerSteward.sol";
import {AaveV3Ethereum} from "aave-address-book/AaveV3Ethereum.sol";
import {GovernanceV3Ethereum} from "aave-address-book/GovernanceV3Ethereum.sol";
import {MiscEthereum} from "aave-address-book/MiscEthereum.sol";
import {IRescuable} from "solidity-utils/contracts/utils/interfaces/IRescuable.sol";
import {IWithGuardian} from "solidity-utils/contracts/access-control/interfaces/IWithGuardian.sol";

interface IStakeManager {
    function setCurrentEpoch(uint256 _currentEpoch) external;
}

/// @dev forge test --match-path=tests/asset-manager/stmatic-withdrawer/StakedTokenWithdrawerStewardTest.t.sol -vv
contract StakedTokenWithdrawerStewardTest is Test {
    address public constant OWNER = GovernanceV3Ethereum.EXECUTOR_LVL_1;
    address public constant GUARDIAN = MiscEthereum.PROTOCOL_GUARDIAN;
    address public constant COLLECTOR = address(AaveV3Ethereum.COLLECTOR);
    // https://etherscan.io/address/0x9ee91F9f426fA633d227f7a9b000E28b9dfd8599
    address public constant ST_MATIC =
        0x9ee91F9f426fA633d227f7a9b000E28b9dfd8599;

    StakedTokenWithdrawerSteward public withdrawer;

    event StartedWithdrawal(
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

contract StartWithdrawTest is StakedTokenWithdrawerStewardTest {
    uint256 amount = 1_000e18;

    function test_success() public {
        vm.startPrank(GUARDIAN);
        deal(ST_MATIC, address(withdrawer), amount);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        vm.expectEmit(true, true, false, true, address(withdrawer));
        emit StartedWithdrawal(ST_MATIC, amounts, 0);
        withdrawer.startWithdrawStMatic(amount);

        uint256 amountAfter = IERC20(ST_MATIC).balanceOf(address(withdrawer));

        assertEq(amountAfter, 0);

        vm.stopPrank();
    }
}

contract FinalizeWithdrawTest is StakedTokenWithdrawerStewardTest {
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
    uint256 WITHDRAWAL_AMOUNT = 1_000e18;

    function test_revertsIf_invalidCaller() public {
        deal(ST_MATIC, address(withdrawer), WITHDRAWAL_AMOUNT);
        vm.expectRevert(IRescuable.OnlyRescueGuardian.selector);
        withdrawer.emergencyTokenTransfer(
            ST_MATIC,
            COLLECTOR,
            WITHDRAWAL_AMOUNT
        );
    }

    function test_successful_governanceCaller() public {
        uint256 initialCollectorBalance = IERC20(ST_MATIC).balanceOf(COLLECTOR);
        deal(ST_MATIC, address(withdrawer), WITHDRAWAL_AMOUNT);
        vm.startPrank(OWNER);
        withdrawer.emergencyTokenTransfer(
            ST_MATIC,
            COLLECTOR,
            WITHDRAWAL_AMOUNT
        );
        vm.stopPrank();

        assertEq(
            IERC20(ST_MATIC).balanceOf(COLLECTOR),
            initialCollectorBalance + WITHDRAWAL_AMOUNT
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
        vm.expectRevert(IRescuable.OnlyRescueGuardian.selector);
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
