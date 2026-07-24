# API Reference

Base URL: `http://localhost:3000` (local) · `https://api.comebackhere.xyz` (production)

All endpoints accept and return `application/json`. Authenticated routes require a
`Authorization: Bearer <token>` header unless noted otherwise.

---

## Treasury

The treasury API exposes settlement lifecycle management on top of the
[Treasury contract](./contract-interaction-guide.md#treasury-contract).

### `GET /api/treasury/settlements`

Returns the list of all pending settlements.

**Response `200 OK`:**

```json
{
  "settlements": [
    {
      "id": 42,
      "status": "pending",
      "amount": "500.00",
      "token": "USDC",
      "merchant": "GXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
      "created_at": "2026-07-01T10:00:00Z"
    }
  ]
}
```

---

### `POST /api/treasury/propose`

Proposes a new settlement for multi-sig approval.

**Request body:**

```json
{
  "merchant": "GXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  "amount": "500.00",
  "token_contract": "CXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  "invoice_id": "inv_01J0ABCDE"
}
```

**Response `201 Created`:**

```json
{
  "settlement_id": 42,
  "status": "pending",
  "threshold_required": 2,
  "approvals_received": 0
}
```

---

### `POST /api/treasury/approve`

Submits a signer's approval for a pending settlement.

**Request body:**

```json
{
  "settlement_id": 42,
  "signer": "GXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
}
```

**Response `200 OK`:**

```json
{
  "settlement_id": 42,
  "approvals_received": 1,
  "threshold_required": 2,
  "status": "pending"
}
```

---

### `POST /api/treasury/execute`

Executes a fully-approved settlement on-chain.

**Request body:**

```json
{
  "settlement_id": 42,
  "signer": "GXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  "token_contract": "CXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
}
```

**Response `200 OK`:**

```json
{
  "settlement_id": 42,
  "status": "executed",
  "tx_hash": "a1b2c3d4..."
}
```

---

### `GET /api/treasury/on-hold-settlements`

Returns all settlements that are currently on hold.
A hold is placed when a signer flags a settlement as requiring manual review before
execution can proceed.

See also: [`hold_settlement` contract entrypoint](./contract-interaction-guide.md#hold_settlement).

**Query parameters:**

| Parameter | Type   | Required | Description                                    |
|-----------|--------|----------|------------------------------------------------|
| `page`    | number | No       | Page number (1-based, default: `1`)            |
| `limit`   | number | No       | Results per page (default: `20`, max: `100`)   |

**Response `200 OK`:**

```json
{
  "settlements": [
    {
      "id": 7,
      "status": "on_hold",
      "amount": "1200.00",
      "token": "USDC",
      "merchant": "GXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
      "held_by": "GYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY",
      "hold_reason": "Merchant KYC under review",
      "held_at": "2026-07-10T14:32:00Z",
      "created_at": "2026-07-10T09:00:00Z"
    }
  ],
  "total": 1,
  "page": 1,
  "limit": 20
}
```

**Error responses:**

| Status | Description                                 |
|--------|---------------------------------------------|
| `401`  | Missing or invalid bearer token             |
| `500`  | Internal server error or RPC connectivity   |

---

### `POST /api/treasury/release-hold`

Releases a held settlement, restoring it to its pre-hold state so the normal
approval and execution flow can resume.

See also: [`release_hold` contract entrypoint](./contract-interaction-guide.md#release_hold).

**Request body:**

```json
{
  "settlement_id": 7,
  "signer": "GYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY"
}
```

| Field           | Type   | Required | Description                                     |
|-----------------|--------|----------|-------------------------------------------------|
| `settlement_id` | number | Yes      | ID of the held settlement to release            |
| `signer`        | string | Yes      | Public key of the authorised signer releasing the hold |

**Response `200 OK`:**

```json
{
  "settlement_id": 7,
  "status": "pending",
  "tx_hash": "d4e5f6a7...",
  "released_at": "2026-07-11T08:15:00Z"
}
```

**Error responses:**

| Status | Body `error`                   | Description                                       |
|--------|--------------------------------|---------------------------------------------------|
| `400`  | `"settlement_not_on_hold"`     | The settlement is not currently held              |
| `401`  | `"unauthorized"`               | Missing or invalid bearer token                   |
| `403`  | `"unauthorized_signer"`        | `signer` is not an authorised treasury signer     |
| `404`  | `"settlement_not_found"`       | No settlement with the given ID exists            |
| `409`  | `"contract_paused"`            | Treasury contract is currently paused             |
| `500`  | `"internal_error"`             | Internal server error or RPC connectivity         |

---

### `POST /api/treasury/escalate-hold`

Escalates a held settlement to the on-chain dispute-resolution flow.
Calling this route invokes `raise_dispute` on the treasury contract and begins a
multi-sig governance vote among the configured signers.

See also: [`raise_dispute` contract entrypoint](./contract-interaction-guide.md#raise_dispute).

**Request body:**

```json
{
  "settlement_id": 7,
  "signer": "GYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY",
  "reason": "Merchant disputes the invoice amount — pending arbitration"
}
```

| Field           | Type   | Required | Description                                                    |
|-----------------|--------|----------|----------------------------------------------------------------|
| `settlement_id` | number | Yes      | ID of the settlement to escalate                               |
| `signer`        | string | Yes      | Public key of the authorised signer raising the dispute        |
| `reason`        | string | Yes      | Human-readable description of the dispute (max 512 chars)      |

**Response `200 OK`:**

```json
{
  "settlement_id": 7,
  "status": "disputed",
  "dispute_id": 3,
  "tx_hash": "f8a9b0c1...",
  "escalated_at": "2026-07-11T09:00:00Z"
}
```

**Error responses:**

| Status | Body `error`              | Description                                         |
|--------|---------------------------|-----------------------------------------------------|
| `400`  | `"reason_required"`       | `reason` field is missing or blank                  |
| `401`  | `"unauthorized"`          | Missing or invalid bearer token                     |
| `403`  | `"unauthorized_signer"`   | `signer` is not an authorised treasury signer       |
| `404`  | `"settlement_not_found"`  | No settlement with the given ID exists              |
| `409`  | `"contract_paused"`       | Treasury contract is currently paused               |
| `500`  | `"internal_error"`        | Internal server error or RPC connectivity           |

---

## Invoice

### `POST /api/invoice/create`

Creates a new invoice and locks the amount in escrow on-chain.

**Request body:**

```json
{
  "merchant": "GXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  "amount": "100.00",
  "token_contract": "CXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  "description": "SaaS subscription — July 2026"
}
```

**Response `201 Created`:**

```json
{
  "invoice_id": "inv_01J0ABCDE",
  "on_chain_id": 18,
  "status": "open",
  "created_at": "2026-07-01T10:00:00Z"
}
```

---

### `POST /api/invoice/mark-paid`

Marks an invoice as paid after settlement funds are confirmed.

**Request body:**

```json
{
  "invoice_id": "inv_01J0ABCDE",
  "settlement_id": 42
}
```

**Response `200 OK`:**

```json
{
  "invoice_id": "inv_01J0ABCDE",
  "status": "paid",
  "paid_at": "2026-07-01T11:00:00Z"
}
```

---

## Health

### `GET /health`

Returns backend and RPC connectivity status.

**Response `200 OK`:**

```json
{
  "status": "ok",
  "rpc": "reachable",
  "db": "connected"
}
```

### `GET /health/rpc`

Checks Soroban RPC reachability and current ledger.

**Response `200 OK`:**

```json
{
  "rpc": "reachable",
  "network": "mainnet",
  "ledger": 54321678
}
```

---

## Further Reading

- [Contract Interaction Guide](./contract-interaction-guide.md)
- [Dev Environment Setup](./dev-environment.md)
