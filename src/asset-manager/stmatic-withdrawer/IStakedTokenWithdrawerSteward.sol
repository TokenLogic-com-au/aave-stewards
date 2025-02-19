// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title IStakedTokenWithdrawerSteward
 * @dev The interface of StakedTokenWithdrawerSteward
 */
interface IStakedTokenWithdrawerSteward {
    /**
     * @dev Emitted when a new Withdrawal is requested
     * @param token The address of token
     * @param amounts The amounts requested to be withdrawn
     * @param index the storage index of the respective requestIds used to finalize the withdrawal
     */
    event StartedWithdrawal(
        address indexed token,
        uint256[] amounts,
        uint256 indexed index
    );

    /**
     * @dev Emitted when a new Withdrawal is requested
     * @param token The address of token
     * @param amount The withdrawn amount to collector
     * @param index The storage index of the respective requestIds used to finalize the withdrawal
     */
    event FinalizedWithdrawal(
        address indexed token,
        uint256 amount,
        uint256 indexed index
    );

    /// @dev Reverts if withdraw request is invalid
    error InvalidRequest();

    /**
     * @dev Starts a new withdrawal on stMatic
     * @param amount The amount to be withdrawn. this amount should be deposited withdrawer before this action
     */
    function startWithdrawStMatic(uint256 amount) external;

    /// @notice Starts a new withdrawal on wstEth
    /// @param amounts a list of amounts to be withdrawn. each amount must be > 100 wei and < 1000 ETH
    function startWithdrawWstEth(uint256[] calldata amounts) external;

    /// @notice Finalizes a withdrawal
    /// @param index The index of the withdrawal request data of the withdrawal to be finalized
    function finalizeWithdraw(uint256 index) external;
}
