# Contract Interaction Guide

This guide describes how the COMEBACKHERE backend interacts with the on-chain Soroban contracts.
Contract ABIs live in `abis/` and are consumed by `comebackhere-backend`.

## Contracts

| Contract   | ABI file              | Purpose                                    |
|------------|-----------------------|--------------------------------------------|
| invoice    | `abis/invoice.json`   | Invoice lifecycle: creation, payment, refund, expiry |
| treasury   | `abis/treasury.json`  | Settlement flow, holds, disputes, token management |
| compliance | `abis/compliance.json`| Address allow/block list and admin controls |

---

## Treasury Contract

The treasury contract (`TREASURY_CONTRACT_ID`) manages the full settlement lifecycle,
including approval thresholds, multi-sig governance, holds, and disputes.

### Entrypoints relevant to the hold/escalation flow

#### `hold_settlement`

Places an active settlement on hold, preventing execution until explicitly released
or escalated through the dispute path.

**Parameters:**

| Name            | Type    | Description                              |
|-----------------|---------|------------------------------------------|
| `signer`        | Address | Authorised signer initiating the hold    |
| `settlement_id` | u64     | ID of the settlement to place on hold    |
| `reason`        | String  | Human-readable reason for the hold       |

**Emitted event:** `settlement_held`

**Errors:**

| Code | Name              | Condition                                  |
|------|-------------------|--------------------------------------------|
| 3    | SettlementNotFound| No settlement with the given ID exists     |
| 8    | ContractPaused    | Contract is currently paused               |
| 9    | Unauthorized      | Caller is not an authorised signer         |
| 15   | SettlementOnHold  | Settlement is already on hold              |

---

#### `release_hold`

Releases a previously held settlement, restoring it to its pre-hold state so it can
proceed through the normal approval and execution path.

**Parameters:**

| Name            | Type    | Description                              |
|-----------------|---------|------------------------------------------|
| `signer`        | Address | Authorised signer releasing the hold     |
| `settlement_id` | u64     | ID of the held settlement to release     |

**Emitted event:** `settlement_released`

**Errors:**

| Code | Name              | Condition                                  |
|------|-------------------|--------------------------------------------|
| 3    | SettlementNotFound| No settlement with the given ID exists     |
| 8    | ContractPaused    | Contract is currently paused               |
| 9    | Unauthorized      | Caller is not an authorised signer         |

---

#### `raise_dispute`

Escalates a held or disputed settlement to the governance dispute-resolution path.
Triggers a vote among the configured signers.

**Parameters:**

| Name            | Type    | Description                              |
|-----------------|---------|------------------------------------------|
| `signer`        | Address | Signer raising the dispute               |
| `settlement_id` | u64     | ID of the settlement being disputed      |
| `reason`        | String  | Description of the dispute               |

**Emitted event:** `dispute_raised`

**Errors:**

| Code | Name              | Condition                                  |
|------|-------------------|--------------------------------------------|
| 3    | SettlementNotFound| No settlement with the given ID exists     |
| 8    | ContractPaused    | Contract is currently paused               |
| 9    | Unauthorized      | Caller is not an authorised signer         |

---

## Invoice Contract

The invoice contract (`INVOICE_CONTRACT_ID`) manages the full invoice lifecycle.

### Key entrypoints

| Function          | Description                                      |
|-------------------|--------------------------------------------------|
| `create_invoice`  | Creates a new invoice and locks funds in escrow  |
| `mark_paid`       | Marks invoice as paid after settlement           |
| `cancel_invoice`  | Cancels an open invoice                          |
| `request_refund`  | Initiates a refund for a paid invoice            |
| `release_escrow`  | Releases held escrow after resolution            |

---

## Compliance Contract

The compliance contract (`COMPLIANCE_CONTRACT_ID`) maintains an allow/block list
for addresses participating in the protocol.

### Key entrypoints

| Function              | Description                                      |
|-----------------------|--------------------------------------------------|
| `allow_address`       | Adds an address to the allow list                |
| `block_address`       | Blocks an address from participating             |
| `allow_address_until` | Temporarily allows an address until a timestamp  |
| `is_allowed`          | Queries whether an address is currently allowed  |

---

## Further Reading

- [API Reference](./api-reference.md)
- [Mainnet Deployment](./MAINNET_DEPLOYMENT.md)
- [Dev Environment Setup](./dev-environment.md)
