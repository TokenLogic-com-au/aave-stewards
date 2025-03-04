// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableWithGuardian} from "solidity-utils/contracts/access-control/OwnableWithGuardian.sol";
import {IRescuable721} from "solidity-utils/contracts/utils/interfaces/IRescuable721.sol";
import {PermissionlessRescuable, IPermissionlessRescuable} from "solidity-utils/contracts/utils/PermissionlessRescuable.sol";
import {RescuableBase, IRescuableBase} from "solidity-utils/contracts/utils/RescuableBase.sol";
import {AaveV3Ethereum, AaveV3EthereumAssets} from "aave-address-book/AaveV3Ethereum.sol";
import {GovernanceV3Ethereum} from "aave-address-book/GovernanceV3Ethereum.sol";
import {MiscEthereum} from "aave-address-book/MiscEthereum.sol";

import {IStakedTokenWithdrawerSteward} from "./IStakedTokenWithdrawerSteward.sol";
import {IStMatic} from "./interfaces/IStMatic.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {IWithdrawalQueueERC721} from "./interfaces/IWithdrawalQueueERC721.sol";

/**
 * @title StakedTokenWithdrawerSteward
 * @author TokenLogic
 * @notice This contract facilitates withdrawals of stMATIC and wstETH tokens through the Lido staking mechanism
 * and transfers the withdrawn funds to the Aave V3 Collector contract.
 * @dev This contract is owned and controlled by Aave Governance.
 * - Only the contract owner or guardian can request withdrawals.
 * - Ensures proper ownership verification before finalizing withdrawals.
 * - Transfers funds directly to the Aave V3 Collector, reducing the risk of misuse.
 * - Uses SafeERC20 to mitigate risks associated with ERC20 token transfers.
 * - Rescue functions allow recovery of mistakenly sent assets.
 */
contract StakedTokenWithdrawerSteward is
    IStakedTokenWithdrawerSteward,
    IRescuable721,
    OwnableWithGuardian,
    PermissionlessRescuable
{
    using SafeERC20 for IERC20;

    /**
     * @notice Represents a request to withdraw tokens.
     * @dev This struct stores the token address and an array of associated request IDs.
     * @param token The address of the token to be withdrawn. It can be StMatic or WstEth
     * @param requestIds An array of request IDs corresponding to the withdrawal requests.
     */
    struct WithdrawRequest {
        address token;
        uint256[] requestIds;
    }

    /// @dev Auto incrementing index to store requestIds of withdrawals
    uint256 public nextIndex;
    /// @dev Minimum check point to reduce gas when get hints from WstEthWithdrawalQueue
    uint256 public minCheckpointIndex;

    /// @dev Stores withdraw request
    mapping(uint256 => WithdrawRequest) public requests;

    /// https://etherscan.io/address/0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1
    address public constant WSTETH_WITHDRAWAL_QUEUE =
        0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1;

    /// https://etherscan.io/address/0x9ee91F9f426fA633d227f7a9b000E28b9dfd8599
    address public constant ST_MATIC =
        0x9ee91F9f426fA633d227f7a9b000E28b9dfd8599;

    constructor()
        OwnableWithGuardian(
            GovernanceV3Ethereum.EXECUTOR_LVL_1,
            MiscEthereum.PROTOCOL_GUARDIAN
        )
    {
        IERC20(ST_MATIC).approve(ST_MATIC, type(uint256).max);
        IERC20(AaveV3EthereumAssets.wstETH_UNDERLYING).approve(
            WSTETH_WITHDRAWAL_QUEUE,
            type(uint256).max
        );
        minCheckpointIndex = IWithdrawalQueueERC721(WSTETH_WITHDRAWAL_QUEUE)
            .getLastCheckpointIndex();
    }

    /// @inheritdoc IStakedTokenWithdrawerSteward
    function startWithdrawStMatic(uint256 amount) external onlyOwnerOrGuardian {
        uint256 index = nextIndex++;

        uint256[] memory requestIds = new uint256[](1);
        requestIds[0] = IStMatic(ST_MATIC).requestWithdraw(
            amount,
            address(this)
        );

        requests[index] = WithdrawRequest({
            token: ST_MATIC,
            requestIds: requestIds
        });

        emit StartedStMaticWithdrawal(ST_MATIC, amount, index);
    }

    /// @inheritdoc IStakedTokenWithdrawerSteward
    function startWithdrawWstEth(
        uint256[] calldata amounts
    ) external onlyOwnerOrGuardian {
        uint256 index = nextIndex++;
        uint256[] memory requestIds = IWithdrawalQueueERC721(
            WSTETH_WITHDRAWAL_QUEUE
        ).requestWithdrawalsWstETH(amounts, address(this));

        requests[index] = WithdrawRequest({
            token: AaveV3EthereumAssets.wstETH_UNDERLYING,
            requestIds: requestIds
        });
        emit StartedWstEthWithdrawal(
            AaveV3EthereumAssets.wstETH_UNDERLYING,
            amounts,
            index
        );
    }

    /// @inheritdoc IStakedTokenWithdrawerSteward
    function finalizeWithdraw(uint256 index) external {
        WithdrawRequest memory request = requests[index];
        uint256 amount;
        if (request.token == ST_MATIC) {
            amount = _finalizeWithdrawStMatic(request.requestIds[0]);
        } else if (request.token == AaveV3EthereumAssets.wstETH_UNDERLYING) {
            amount = _finalizeWithdrawWstEth(request.requestIds);
        } else {
            revert InvalidRequest();
        }

        delete requests[index];

        emit FinalizedWithdrawal(request.token, amount, index);
    }

    /**
     * @dev Finalize withdrawal of stMatic
     * @param requestId The id of request
     */
    function _finalizeWithdrawStMatic(
        uint256 requestId
    ) internal returns (uint256) {
        IERC721 poLidoNft = IERC721(IStMatic(ST_MATIC).poLidoNFT());
        poLidoNft.approve(ST_MATIC, requestId);
        IStMatic(ST_MATIC).claimTokens(requestId);

        IERC20 token = IERC20(IStMatic(ST_MATIC).token());

        uint256 amount = token.balanceOf(address(this));
        token.transfer(address(AaveV3Ethereum.COLLECTOR), amount);

        return amount;
    }

    /**
     * @dev Finalize withdrawal of wstEth
     * @param requestIds The ids of request on withdrawal queue
     */
    function _finalizeWithdrawWstEth(
        uint256[] memory requestIds
    ) internal onlyOwnerOrGuardian returns (uint256) {
        uint256[] memory hintIds = IWithdrawalQueueERC721(
            WSTETH_WITHDRAWAL_QUEUE
        ).findCheckpointHints(
                requestIds,
                minCheckpointIndex,
                IWithdrawalQueueERC721(WSTETH_WITHDRAWAL_QUEUE)
                    .getLastCheckpointIndex()
            );

        IWithdrawalQueueERC721(WSTETH_WITHDRAWAL_QUEUE).claimWithdrawalsTo(
            requestIds,
            hintIds,
            address(this)
        );

        uint256 amount = address(this).balance;

        IWETH(AaveV3EthereumAssets.WETH_UNDERLYING).deposit{value: amount}();

        IERC20(AaveV3EthereumAssets.WETH_UNDERLYING).transfer(
            address(AaveV3Ethereum.COLLECTOR),
            amount
        );

        return amount;
    }

    /// @inheritdoc IRescuableBase
    function maxRescue(
        address erc20Token
    ) public view override(IRescuableBase, RescuableBase) returns (uint256) {
        return type(uint256).max;
    }

    /// @inheritdoc IPermissionlessRescuable
    function whoShouldReceiveFunds() public view override returns (address) {
        return address(AaveV3Ethereum.COLLECTOR);
    }

    /// @inheritdoc IRescuable721
    function emergency721TokenTransfer(
        address erc721Token,
        address to,
        uint256 tokenId
    ) external override onlyOwnerOrGuardian {
        IERC721(erc721Token).transferFrom(address(this), to, tokenId);

        emit ERC721Rescued(msg.sender, erc721Token, to, tokenId);
    }

    receive() external payable {}
}
