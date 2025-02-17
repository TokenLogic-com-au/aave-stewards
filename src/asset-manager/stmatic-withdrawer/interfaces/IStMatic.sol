/// @title StMATIC interface.
/// @author 2021 ShardLabs
interface IStMatic {
    /// @notice The request withdraw struct.
    /// @param amount2WithdrawFromStMATIC amount in Matic.
    /// @param validatorNonce validator nonce.
    /// @param requestEpoch request epoch.
    /// @param validatorAddress validator share address.
    struct RequestWithdraw {
        uint256 amount2WithdrawFromStMATIC;
        uint256 validatorNonce;
        uint256 requestEpoch;
        address validatorAddress;
    }
    /// @notice StakeManager interface.
    function stakeManager() external view returns (address);

    /// @notice LidoNFT interface.
    function poLidoNFT() external view returns (address);

    /// @notice dao address.
    function dao() external view returns (address);

    /// @notice Matic ERC20 token.
    function token() external view returns (address);

    /// @notice token to WithdrawRequest mapping.
    function token2WithdrawRequest(
        uint256 _requestId
    ) external view returns (uint256, uint256, uint256, address);

    function getToken2WithdrawRequests(
        uint256 _tokenId
    ) external view returns (RequestWithdraw[] memory);

    /// @notice DAO Role.
    function DAO() external view returns (bytes32);

    /// @notice PAUSE_ROLE Role.
    function PAUSE_ROLE() external view returns (bytes32);

    /// @notice UNPAUSE_ROLE Role.
    function UNPAUSE_ROLE() external view returns (bytes32);

    /// @notice Stores users request to withdraw into a RequestWithdraw struct
    /// @param _amount - Amount of StMATIC that is requested to withdraw
    /// @param _referral - referral address.
    /// @return NFT token id.
    function requestWithdraw(
        uint256 _amount,
        address _referral
    ) external returns (uint256);

    /// @notice Claims tokens from validator share and sends them to the
    /// StMATIC contract
    /// @param _tokenId - Id of the token that is supposed to be claimed
    function claimTokens(uint256 _tokenId) external;

    /// @notice Unpauses the contract
    function unpause() external;
}
