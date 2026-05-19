# OFTBridgeSteward

`OFTBridgeSteward` is an Aave Steward that bridges USDT from a non-Ethereum chain to the Ethereum mainnet Collector using USDT0 OFT (Omnichain Fungible Token) over LayerZero V2. The transfer is 1:1 with no slippage.

The steward is unidirectional: every deployed instance bridges *to* Ethereum mainnet. The destination endpoint and receiver address are immutable, set in the contract's code (see `DESTINATION_EID` and `MAINNET_COLLECTOR`).

## How USDT0 Works

USDT0 is Tether's official cross-chain solution using LayerZero's OFT standard. It enables unified USDT liquidity across chains without wrapped tokens.

### Architecture

- **On Ethereum (destination):** USDT0 uses `OAdapterUpgradeable` to release native USDT on receipt of a LayerZero message. The steward is **not** deployed on Ethereum.
- **On other chains (source):** USDT0 uses `OUpgradeable` which burns USDT0 on send. The steward is deployed on these chains and calls `send` on the local OFT.

### Key Benefits

- **No Slippage:** 1:1 burn-on-source / release-on-destination mechanism.
- **Unified Liquidity:** All USDT0 is backed 1:1 by USDT locked on Ethereum.
- **Dual DVN Security:** Verified by both the LayerZero DVN and the USDT0 DVN.

## Functions

### `bridge(uint256 amount, uint256 minAmountLD, uint256 maxFee)`

Bridges `amount` USDT to the immutable `MAINNET_COLLECTOR` on Ethereum (`DESTINATION_EID`). Restricted to owner or guardian.

- The steward pulls `amount` USDT from the local Collector via `ICollector.transfer`, so it must hold the Collector `FUNDS_ADMIN` role.
- The native LayerZero fee is paid from the steward's own balance. It can be either pre-funded (use `receive()` or `transfer`) or supplied as `msg.value` on the same call — both add to `address(this).balance`, which is what the contract checks.
- `minAmountLD` is the slippage floor passed through to the OFT.
- `maxFee` caps the LayerZero `nativeFee`. The call reverts with `MaxFeeExceeded` if the quoted fee exceeds it. Always quote the fee first and pass a snug `maxFee` to avoid getting front-run by a fee spike.
- LayerZero refunds any unused fee directly to the local Collector (the refund recipient is set to `COLLECTOR`).

### `quoteSendFee(uint256 amount, uint256 minAmountLD) returns (uint256)`

Returns the native-token fee LayerZero will charge for `bridge(amount, minAmountLD, …)`. Use this to size `maxFee` and the value/balance to fund.

### `quoteAmountReceived(uint256 amount) returns (uint256)`

Returns the amount of USDT the Mainnet Collector will get for an `amount` send (after any OFT-level dust truncation). For USDT0 this equals `amount` (no slippage), but always re-quote on-chain rather than assume.

### `rescueToken(address token)` / `rescueEth()`

Sweeps the steward's full balance of `token` (or ETH) back to the local Collector. Restricted to owner or guardian.

## Usage Pattern

```solidity
// 1. Quote the expected received amount on Ethereum.
uint256 expectedReceived = bridge.quoteAmountReceived(amount);

// 2. Quote the LayerZero native fee.
uint256 fee = bridge.quoteSendFee(amount, expectedReceived);

// 3. Grant the steward FUNDS_ADMIN on the local Collector (one-time).
IAccessControl(address(collector)).grantRole(
    ICollector(address(collector)).FUNDS_ADMIN_ROLE(),
    address(bridge)
);

// 4. Execute the bridge. Either pre-fund the steward with `fee` wei
//    of native, or supply it as msg.value on the same call.
bridge.bridge{value: fee}(amount, expectedReceived, fee);
```

## Permissions

The contract uses `OwnableWithGuardian`. The owner should be the local network's Level 1 Executor (Aave Governance); the guardian is a trusted ops role.

The steward must also hold the local Collector `FUNDS_ADMIN` role so it can call `ICollector.transfer`. Note that this role is broader than what `bridge()` actually exercises — it grants the steward the ability to move *any* token from the Collector to *any* address. A bug or future extension to the steward could in principle exfiltrate other Collector funds, so the role grant is a trust assumption that should be considered when reviewing changes to the steward.

The owner or guardian can:

- Call `bridge()` to initiate transfers.
- Call `rescueToken()` / `rescueEth()` to sweep stuck assets back to the local Collector.

Only the owner can:

- Transfer ownership.

There is no allow-list of receivers: `MAINNET_COLLECTOR` is a constant in the contract's code.

## Security Considerations

- **Slippage protection:** `minAmountLD` enforces the floor for tokens received on Ethereum. Quote `quoteAmountReceived` immediately before sending.
- **Fee protection:** `maxFee` caps the LayerZero native fee, avoiding open-ended drains if quoting and execution land in different blocks.
- **Approval hygiene:** The steward `forceApprove`s the OFT for exactly `amount`, then resets to `0` after `send`, so no allowance is left dangling.
- **Refund routing:** LayerZero's refund recipient is hard-coded to the local `COLLECTOR`, so excess native fee goes back to Aave directly.
- **Rescue path:** Inherits `RescuableBase`; `maxRescue` returns the steward's full token balance, allowing complete sweep.
- **Fixed destination/receiver:** `DESTINATION_EID` (Ethereum mainnet) and `MAINNET_COLLECTOR` are constants, removing destination-spoofing surface.

## Retry Mechanism

LayerZero supports retrying messages that fail to execute on the destination chain. Because verification (DVN attestation) is decoupled from execution, an already-verified message can be re-executed by anyone without resending it from the source chain.

### How to Retry

1. **LayerZero Scan UI:** find the failed message at [layerzeroscan.com](https://layerzeroscan.com/) and trigger a retry.
2. **Direct call:** invoke `lzReceive` on the destination Endpoint contract.

See the [LayerZero debugging documentation](https://docs.layerzero.network/v2/developers/evm/troubleshooting/debugging-messages#retry-message) for details.

## Supported Chains

USDT0 is currently deployed on the chains below. Endpoint IDs / OFT addresses are mirrored in [`OFTConstants.sol`](./OFTConstants.sol).

### Endpoint IDs and OFT Contracts

| Chain    | Role        | Endpoint ID | USDT0 OFT Contract                         | Notes                            |
| -------- | ----------- | ----------- | ------------------------------------------ | -------------------------------- |
| Ethereum | Destination | 30101       | 0x6C96dE32CEa08842dcc4058c14d3aaAD7Fa41dee | OAdapterUpgradeable (locks USDT) |
| Arbitrum | Source      | 30110       | 0x14E4A1B13bf7F943c8ff7C51fb60FA964A298D92 | OUpgradeable                     |
| Polygon  | Source      | 30109       | 0x6BA10300f0DC58B7a1e4c0e41f5daBb7D7829e13 | OUpgradeable                     |
| Optimism | Source      | 30111       | 0xF03b4d9AC1D5d1E7c4cEf54C2A313b9fe051A0aD | OUpgradeable                     |
| Ink      | Source      | 30339       | 0x0200C29006150606B650577BBE7B6248F58470c1 | OUpgradeable (no deploy script)  |
| Plasma   | Source      | 30383       | 0x02ca37966753bDdDf11216B73B16C1dE756A7CF9 | OUpgradeable                     |

The steward is deployed on each *source* chain. Deployment scripts live in [`scripts/DeployOFTBridge.s.sol`](../../../scripts/DeployOFTBridge.s.sol) and currently cover Arbitrum, Polygon, Optimism, and Plasma.

### USDT Token Addresses

| Chain    | USDT/USDT0 Token                           |
| -------- | ------------------------------------------ |
| Ethereum | 0xdAC17F958D2ee523a2206206994597C13D831ec7 |
| Arbitrum | 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9 |
| Polygon  | 0xc2132D05D31c914a87C6611C10748AEb04B58e8F |
| Optimism | 0x01bFF41798a0BcF287b996046Ca68b395DbC1071 |
| Ink      | 0x0200C29006150606B650577BBE7B6248F58470c1 |
| Plasma   | 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb |

### Not Supported

| Chain     | Reason              |
| --------- | ------------------- |
| Avalanche | No USDT0 deployment |
| Base      | No USDT0 deployment |

## Known Limitations

1. **Destination is fixed to Ethereum mainnet.** A new contract deployment is required to bridge to any other chain.
2. **USDT0 only.** Only USDT transfers within the USDT0 system are supported.
3. **LayerZero native fee.** A small native-token fee is required for messaging. Quote it with `quoteSendFee` before each call.

## References

- [USDT0 Documentation](https://docs.usdt0.to/)
- [USDT0 Deployments](https://docs.usdt0.to/technical-documentation/developer/usdt0-deployments)
- [LayerZero V2 OFT Standard](https://docs.layerzero.network/v2/developers/evm/oft/native-transfer)
