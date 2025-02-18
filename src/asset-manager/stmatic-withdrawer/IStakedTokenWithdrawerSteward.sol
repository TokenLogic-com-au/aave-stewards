// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title IStakedTokenWithdrawerSteward
 * @dev The interface of StakedTokenWithdrawerSteward
 */
interface IStakedTokenWithdrawerSteward {
    /**
     * @dev Emitted when a new Withdrawal is requested
     * @param amount The amount requested to be withdrawn
     * @param tokenId The tokenId of NFT to handle claim tokens
     */
    event StartedWithdrawal(
        address indexed token,
        uint256 amount,
        uint256 indexed tokenId
    );

    /**
     * @dev Emitted when a new Withdrawal is requested
     * @param amount The withdrawn amount to collector
     * @param tokenId The tokenId of NFT to handle claim tokens
     */
    event FinalizedWithdrawal(
        address indexed token,
        uint256 amount,
        uint256 indexed tokenId
    );

    /// @dev Reverts when balance of withdrawer insufficient
    error InsufficientBalance();

    /// @dev Reverts when input invalid not owned tokenId
    error InvalidOwner();

    /**
     * @dev Return address of StMatic contract
     * @return The address of StMatic contract
     */
    function ST_MATIC() external view returns (address);

    /**
     * @dev Sends withdraw request to stMatic contract
     * @param amount The amount to be withdrawn. this amount should be deposited withdrawer before this action
     * @return tokenId The id of IPoLido NFT
     */
    function requestWithdrawStMatic(
        uint256 amount
    ) external returns (uint256 tokenId);

    /**
     * @dev Claim MATIC from stMatic contract
     * @param tokenId The id of IPoLido NFT
     */
    function finalizeWithdrawStMatic(uint256 tokenId) external;
}
