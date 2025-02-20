# StakedTokenWithdrawerSteward Smart Contract

## Overview

The `StakedTokenWithdrawerSteward` contract is designed to facilitate the withdrawal of staked tokens, specifically `stMATIC` and `wstETH`, through the Lido staking mechanism. The withdrawn funds are then transferred to the Aave V3 Collector contract. This contract is part of the TokenLogic ecosystem and is intended to be used by the Aave protocol for managing staked token withdrawals.

## Key Features

- **Withdrawal Initiation**: The contract allows the owner or guardian to initiate withdrawals for `stMATIC` and `wstETH` tokens.
- **Withdrawal Finalization**: Once the withdrawal request is processed, the contract finalizes the withdrawal and transfers the funds to the Aave V3 Collector.
- **Event Emission**: The contract emits events to track the initiation and finalization of withdrawals.
- **Rescue Mechanism**: The contract includes a rescue mechanism to recover tokens or ETH in case of accidental transfers.

## Contract Details

### Interfaces

- **IStakedTokenWithdrawerSteward**: Defines the interface for the contract, including events and functions for initiating and finalizing withdrawals.
- **IStMatic**: Interface for interacting with the `stMATIC` token.
- **IWETH**: Interface for interacting with Wrapped ETH (WETH).
- **IWithdrawalQueueERC721**: Interface for interacting with the Lido withdrawal queue for `wstETH`.

### Inherited Contracts

- **OwnableWithGuardian**: Provides ownership and guardian functionality, allowing only the owner or guardian to execute certain functions.
- **Rescuable721**: Provides functionality to rescue ERC721 tokens.
- **RescuableBase**: Provides base functionality for rescuing tokens and ETH.

### Key Functions

#### `startWithdrawStMatic(uint256 amount)`

- **Description**: Initiates a withdrawal request for `stMATIC` tokens.
- **Parameters**:
  - `amount`: The amount of `stMATIC` to withdraw.
- **Restrictions**: Can only be called by the owner or guardian.

#### `startWithdrawWstEth(uint256[] calldata amounts)`

- **Description**: Initiates a withdrawal request for `wstETH` tokens.
- **Parameters**:
  - `amounts`: An array of amounts to withdraw. Each amount must be greater than 100 wei and less than 1000 ETH.
- **Restrictions**: Can only be called by the owner or guardian.

#### `finalizeWithdraw(uint256 index)`

- **Description**: Finalizes a withdrawal request and transfers the withdrawn funds to the Aave V3 Collector.
- **Parameters**:
  - `index`: The index of the withdrawal request to finalize.
- **Restrictions**: Can be called by anyone, but the actual withdrawal logic is restricted to the owner or guardian.

#### `_finalizeWithdrawStMatic(uint256 requestId)`

- **Description**: Internal function to finalize the withdrawal of `stMATIC` tokens.
- **Parameters**:
  - `requestId`: The ID of the withdrawal request.
- **Returns**: The amount of tokens withdrawn.

#### `_finalizeWithdrawWstEth(uint256[] memory requestIds)`

- **Description**: Internal function to finalize the withdrawal of `wstETH` tokens.
- **Parameters**:
  - `requestIds`: An array of withdrawal request IDs.
- **Returns**: The amount of ETH withdrawn.

#### `whoCanRescue()`

- **Description**: Returns the address of the owner who can rescue tokens or ETH.
- **Returns**: The address of the owner.

#### `maxRescue(address)`

- **Description**: Returns the maximum amount of tokens or ETH that can be rescued.
- **Returns**: `type(uint256).max` (unlimited).

### Events

- **StartedWithdrawal**: Emitted when a new withdrawal is initiated.
  - `token`: The address of the token being withdrawn.
  - `amounts`: The amounts requested to be withdrawn.
  - `index`: The storage index of the withdrawal request.

- **FinalizedWithdrawal**: Emitted when a withdrawal is finalized.
  - `token`: The address of the token being withdrawn.
  - `amount`: The amount withdrawn to the collector.
  - `index`: The storage index of the withdrawal request.

### Error

- **InvalidRequest**: Reverts if the withdrawal request is invalid.

### Constants

- **WSTETH_WITHDRAWAL_QUEUE**: The address of the Lido withdrawal queue for `wstETH`.
- **ST_MATIC**: The address of the `stMATIC` token.

### Constructor

- **Description**: Initializes the contract with the Aave V3 Ethereum addresses and sets up approvals for `stMATIC` and `wstETH` tokens.
- **Parameters**: None.

### Fallback and Receive Functions

- **fallback()**: Allows the contract to receive ETH.
- **receive()**: Allows the contract to receive ETH.

## Usage

1. **Deploy the Contract**: Deploy the `StakedTokenWithdrawerSteward` contract on the Ethereum mainnet.
2. **Initiate Withdrawal**: The owner or guardian can call `startWithdrawStMatic` or `startWithdrawWstEth` to initiate a withdrawal.
3. **Finalize Withdrawal**: Once the withdrawal request is processed, call `finalizeWithdraw` to finalize the withdrawal and transfer the funds to the Aave V3 Collector.
4. **Rescue Tokens**: In case of accidental transfers, the owner can rescue tokens or ETH using the rescue functions.

## Security Considerations

- **Access Control**: Only the owner or guardian can initiate and finalize withdrawals.
- **Input Validation**: The contract validates input amounts to ensure they are within acceptable ranges.
- **Rescue Mechanism**: The contract includes a rescue mechanism to recover tokens or ETH in case of accidental transfers.

## Author

- **TokenLogic**: The team behind the development and maintenance of this contract.

-