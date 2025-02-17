// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title IAaveStMaticWithdrawerSteward
 * @dev The interface of AaveStMaticWithdrawer
 */
interface IAaveStMaticWithdrawerSteward {
    /**
     * @dev emitted when a new Withdrawal is requested
     * @param amount the amount requested to be withdrawn
     * @param tokenId the tokenId of NFT to handle claim tokens
     */
    event StartedWithdrawal(uint256 amount, uint256 indexed tokenId);

    /**
     * @dev emitted when a new Withdrawal is requested
     * @param amount the amount of WETH withdrawn to collector
     * @param tokenId the tokenId of NFT to handle claim tokens
     */
    event FinalizedWithdrawal(uint256 amount, uint256 indexed tokenId);

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
    function requestWithdraw(uint256 amount) external returns (uint256 tokenId);

    /**
     * @dev claim MATIC from stMatic contract
     * @param tokenId the id of IPoLido NFT
     */
    function finalizeWithdraw(uint256 tokenId) external;

    /// @dev reverts when balance of helper insufficient
    error InsufficientBalance();

    /// @dev reverts when input invalid not owned tokenId
    error InvalidOwner();
}
