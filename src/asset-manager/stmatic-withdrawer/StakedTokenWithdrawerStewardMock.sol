// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableWithGuardian} from "solidity-utils/contracts/access-control/OwnableWithGuardian.sol";
import {Rescuable721, Rescuable} from "solidity-utils/contracts/utils/Rescuable721.sol";
import {RescuableBase, IRescuableBase} from "solidity-utils/contracts/utils/RescuableBase.sol";
import {AaveV3Ethereum} from "aave-address-book/AaveV3Ethereum.sol";
import {GovernanceV3Ethereum} from "aave-address-book/GovernanceV3Ethereum.sol";
import {MiscEthereum} from "aave-address-book/MiscEthereum.sol";

import {IStakedTokenWithdrawerSteward} from "./IStakedTokenWithdrawerSteward.sol";
import {IStMatic} from "./interfaces/IStMatic.sol";

/**
 * @title StakedTokenWithdrawerSteward
 * @author TokenLogic
 * @notice This contract facilitates withdrawals of stMATIC tokens through the Lido staking mechanism
 * and transfers the withdrawn funds to the Aave V3 Collector contract.
 */
contract StakedTokenWithdrawerSteward is
    OwnableWithGuardian,
    Rescuable721,
    IStakedTokenWithdrawerSteward
{
    using SafeERC20 for IERC20;

    /// @inheritdoc IStakedTokenWithdrawerSteward
    address public immutable ST_MATIC;

    constructor(
        address stMatic
    )
        OwnableWithGuardian(
            GovernanceV3Ethereum.EXECUTOR_LVL_1,
            0x94A8518B76A3c45F5387B521695024379d43d715
        )
    {
        ST_MATIC = stMatic;
        IERC20(stMatic).approve(address(stMatic), type(uint256).max);
    }

    /// @inheritdoc IStakedTokenWithdrawerSteward
    function requestWithdrawStMatic(
        uint256 amount
    ) external onlyOwnerOrGuardian returns (uint256 tokenId) {
        if (amount > IERC20(ST_MATIC).balanceOf(address(this))) {
            revert InsufficientBalance();
        }

        tokenId = IStMatic(ST_MATIC).requestWithdraw(amount, address(this));

        emit StartedWithdrawal(ST_MATIC, amount, tokenId);
    }

    /// @inheritdoc IStakedTokenWithdrawerSteward
    function finalizeWithdrawStMatic(uint256 tokenId) external {
        IERC721 poLidoNft = IERC721(IStMatic(ST_MATIC).poLidoNFT());
        if (poLidoNft.ownerOf(tokenId) != address(this)) {
            revert InvalidOwner();
        }

        poLidoNft.approve(ST_MATIC, tokenId);
        IStMatic(ST_MATIC).claimTokens(tokenId);

        IERC20 token = IERC20(IStMatic(ST_MATIC).token());

        uint256 amount = token.balanceOf(address(this));
        token.transfer(address(AaveV3Ethereum.COLLECTOR), amount);

        emit FinalizedWithdrawal(ST_MATIC, amount, tokenId);
    }
}
