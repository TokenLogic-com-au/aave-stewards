// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title IStakedTokenWithdrawerSteward
 * @dev The interface of StakedTokenWithdrawerSteward
 */
interface IStakedTokenWithdrawerSteward {
    /**
     * @dev emitted when a new Withdrawal is requested
     * @param amount the amount requested to be withdrawn
     * @param tokenId the tokenId of NFT to handle claim tokens
     */
    event StartedWithdrawal(
        address indexed token,
        uint256 amount,
        uint256 indexed tokenId
    );

    /**
     * @dev emitted when a new Withdrawal is requested
     * @param amount the withdrawn amount to collector
     * @param tokenId the tokenId of NFT to handle claim tokens
     */
    event FinalizedWithdrawal(
        address indexed token,
        uint256 amount,
        uint256 indexed tokenId
    );

    /**
     * @dev return address of StMatic contract
     * @return The address of StMatic contract
     */
    function ST_MATIC() external view returns (address);

    /**
     * @dev sends withdraw request to stMatic contract
     * @param amount the amount to be withdrawn. this amount should be deposited helper before this action
     * @return tokenId the id of IPoLido NFT
     */
    function requestWithdrawStMatic(
        uint256 amount
    ) external returns (uint256 tokenId);

    /**
     * @dev claim MATIC from stMatic contract
     * @param tokenId the id of IPoLido NFT
     */
    function finalizeWithdrawStMatic(uint256 tokenId) external;

    /// @dev reverts when balance of helper insufficient
    error InsufficientBalance();

    /// @dev reverts when input invalid not owned tokenId
    error InvalidOwner();
}
