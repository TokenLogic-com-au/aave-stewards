// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title IStakedTokenWithdrawerSteward
 * @dev The interface for the StakedTokenWithdrawerSteward contract, which facilitates withdrawals of staked tokens (e.g., stMATIC and wstETH) and transfers the withdrawn funds to a collector contract.
 */
interface IStakedTokenWithdrawerSteward {
    /**
     * @dev Emitted when a new StMatic withdrawal is initiated.
     * @param token The address of the token being withdrawn.
     * @param amount The amounts requested to be withdrawn.
     * @param index The storage index of the respective request IDs used to finalize the withdrawal.
     */
    event StartedStMaticWithdrawal(
        address indexed token,
        uint256 amount,
        uint256 indexed index
    );

    /**
     * @dev Emitted when a new WstEth withdrawal is initiated.
     * @param token The address of the token being withdrawn.
     * @param amounts The amounts requested to be withdrawn.
     * @param index The storage index of the respective request IDs used to finalize the withdrawal.
     */
    event StartedWstEthWithdrawal(
        address indexed token,
        uint256[] amounts,
        uint256 indexed index
    );

    /**
     * @dev Emitted when a withdrawal is finalized and the funds are transferred to the collector.
     * @param token The address of the token being withdrawn.
     * @param amount The amount of tokens withdrawn and transferred to the collector.
     * @param index The storage index of the respective request IDs used to finalize the withdrawal.
     */
    event FinalizedWithdrawal(
        address indexed token,
        uint256 amount,
        uint256 indexed index
    );

    /// @dev Reverts if the withdrawal request is invalid (e.g., incorrect token or request ID).
    error InvalidRequest();

    /**
     * @dev Initiates a withdrawal request for stMATIC tokens.
     * @param amount The amount of stMATIC tokens to withdraw. This amount must be deposited into the contract before calling this function.
     */
    function startWithdrawStMatic(uint256 amount) external;

    /**
     * @dev Initiates a withdrawal request for wstETH tokens.
     * @param amounts An array of amounts to withdraw. Each amount must be greater than 100 wei and less than 1000 ETH.
     */
    function startWithdrawWstEth(uint256[] calldata amounts) external;

    /**
     * @dev Finalizes a withdrawal request and transfers the withdrawn funds to the collector.
     * @param index The index of the withdrawal request data to finalize.
     */
    function finalizeWithdraw(uint256 index) external;
}
