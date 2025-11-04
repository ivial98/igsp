---
title: Integration Guide
nav_order: 2
---



# 🔐 1. Authentication and Request Signing

In the **iGSP** standard, all communication between a **Game Provider** and a **Casino Platform** is secured through a shared secret mechanism based on **HMAC signatures**.  
Both parties use the same key pair — issued by the provider — to sign and verify all requests in both directions.

---

## 1.1 Key Issuance

The **Game Provider** generates a unique pair of API credentials for each connected **Casino Platform**:

| Field | Example | Description |
|--------|----------|-------------|
| `api_key` | `gp_live_a14f22...` | Public identifier used in `Authorization` header |
| `secret_key` | `91b2c7a4aadb48b62e...` | Shared secret used to compute and verify signatures |

The provider shares this pair securely with the platform (via admin portal or encrypted channel).  
Both parties store the `secret_key` securely — it must **never** appear in logs, code repositories, or client-side applications.

The **Casino Platform** shares its webhook URL with the **Game Provider**.

### Example configuration

```yaml
integration:
  api_key: "gp_live_a14f22..."
  secret_key: "91b2c7a4aadb48b62e..."
  provider_url: "api.provider.com/igsp/v1"
  platform_hook_url: "api.casino.com/webhooks/igsp/v1"
```

---

## 1.2 Shared Signing Principle

- The **Casino Platform** uses this key pair when making API calls to the provider (e.g., `api.provider.com/igsp/v1/sessions`, `api.provider.com/igsp/v1/games`).
- The **Game Provider** uses the same key pair when sending callbacks or wallet requests back to the platform (e.g., `api.casino.com/webhooks/igsp/v1`).

Each side verifies incoming requests by recalculating the HMAC signature with the shared `secret_key`.

This ensures:
- authenticity of the sender,  
- integrity of the message body, and  
- protection from replay or tampering attacks.

---

## 1.3 Required Headers

| Header | Description | Example |
|--------|-------------|----------|
| `Authorization` | Identifies the integration (contains `api_key`) | `Bearer gp_live_a14f22...` |
| `X-Timestamp` | UTC timestamp of request generation (ISO-8601) | `2025-10-17T12:03:41Z` |
| `X-Signature` | HMAC-SHA256 hash of the request body + timestamp | `7b9a3d2c7f1c9e4a4df2a8d1a` |


---

## 1.4 Signature Generation

The request signature is calculated using the following formula:

```
HMAC_SHA256(secret_key, raw_request_body + X-Timestamp)
```

Both sides must use the **exact JSON string** (without reformatting or spacing differences).

### PHP example

```php
$body = json_encode($requestData, JSON_UNESCAPED_SLASHES);
$timestamp = gmdate('Y-m-d\TH:i:s\Z');

$signature = hash_hmac('sha256', $body . $timestamp, $secretKey);

$headers = [
    'Authorization: Bearer ' . $apiKey,
    'X-Timestamp: ' . $timestamp,
    'X-Signature: ' . $signature,
];
```

---

## 1.5 Signature Verification (Receiving Side)

When receiving a request, the system must:

1. Extract headers: `X-Signature` and `X-Timestamp`.
2. Rebuild the **raw request body** exactly as received.
3. Recalculate the HMAC using the shared `secret_key`.
4. Compare signatures using **constant-time** comparison (`hash_equals` in PHP).
5. Reject if:
   - timestamp difference > 5 minutes, or  
   - signatures do not match.

### PHP verification example

```php
$expected = hash_hmac('sha256', $body . $timestamp, $secretKey);

if (!hash_equals($expected, $receivedSignature)) {
    http_response_code(403);
    echo json_encode(['error' => 'Invalid signature']);
    exit;
}
```

---

## 1.6 Example Exchange

### ▶️ Casino Platform → Game Provider

```http
POST api.provider/igsp/v1/sessions HTTP/1.1
Authorization: Bearer gp_live_a14f22...
X-Timestamp: 2025-10-17T12:03:41Z
X-Signature: 7b9a3d2c7f1c9e4a4df2a8d1a
Content-Type: application/json

{
  "game_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "player_id": "player-912",
  "player_name": "LuckyFox",
  "currency": "EUR",
  "session_id": "sess-20250101-0001",
  "balance": 100.00,
  "device": "desktop",
  "return_url": "https://casino.example.com/lobby",
  "language": "en",
  "is_demo": false
}
```

**Provider validation:**
- recomputes HMAC using same secret  
- ensures request not older than 5 minutes  
- accepts or rejects based on signature
- validates required session fields from the OpenAPI schema

**Provider response:**

```http
HTTP/1.1 201 Created
Content-Type: application/json

{
  "url": "https://games.provider.com/session/launch/abc123"
}
```

---

### ◀️ Game Provider → Casino Platform

```http
POST api.platform.com/webhooks/igsp/v1 HTTP/1.1
Authorization: Bearer gp_live_a14f22...
X-Timestamp: 2025-10-17T12:03:45Z
X-Signature: 13ac9f11c0d78fa...
Content-Type: application/json

{
  "action": "balance",
  "player_id": "player-912",
  "currency": "EUR",
  "session_id": "sess-20250101-0001"
}
```

**Platform validation:**
- uses the same secret key  
- validates timestamp and HMAC  
- checks the player session exists and returns the current balance snapshot

**Platform response:**

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "balance": 100.00
}
```

---

## 1.7 Replay Attack Protection

To avoid reusing valid signatures:

- Validate `X-Timestamp` (±5-minute window).
- Optionally, maintain audit logs.

---

## 1.8 Summary

| Concept | Description |
|----------|--------------|
| **Single Key Pair** | One `api_key` + `secret_key` shared between both parties |
| **Bidirectional HMAC** | Same signature logic applies for both directions |
| **Integrity** | Body + timestamp are always validated |
| **Security** | Replay protection, constant-time comparison, timestamp validation |
| **Simplicity** | Unified implementation reduces integration complexity |

---

# 🎮 2. Provider and Game Import Pipeline

The **iGSP Provider API** exposes everything you need to bootstrap and keep your casino catalog in sync. This chapter covers how to translate the OpenAPI contract (`spec/igsp-providers.yaml`) into a repeatable ETL that populates your platform database with provider and game metadata.

---

## 2.1 Source Specification

- The contract in `spec/igsp-providers.yaml` is the single source of truth for field names, formats, and cursor pagination semantics.  
- Generate a typed client (e.g., with OpenAPI Generator) or load the schema to auto-build validators so responses fail fast when the provider deploys breaking changes.  
- Reuse the HMAC credentials from Chapter 1: every import request must carry the same `Authorization`, `X-Timestamp`, and `X-Signature` headers.  
- Both list endpoints accept `cursor`, `limit`, and `updated_after` query parameters so you can control page size and only fetch fresh changes.

---

## 2.2 Provider Synchronisation (`GET /providers`)

1. Call `GET api.provider.com/igsp/v1/providers` with the signed headers. Supply `updated_after` when you only need to ingest new or recently updated providers.  
2. Iterate using the cursor contract: after each request, persist `response.cursor.next` and pass it back as the `cursor` query parameter until it becomes `null` or `meta.has_more` is `false`.  
3. Upsert each provider by its canonical `id` (UUID). Recommended column mapping:
   - `name`, `slug` -> provider identity.  
   - `currencies[]`, `restricted_countries[]` -> regulate availability.  
   - `images[]` -> store alongside CDN URLs for launcher use.  
   - `min_age`, `min_kyc_level` -> enforce compliance at runtime.
4. Keep the raw JSON for auditing; it accelerates investigations when field semantics evolve.

Example response excerpt:

```json
{
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "NetEnt",
      "currencies": ["USD", "EUR"]
    }
  ],
  "cursor": {
    "next": "eyJvZmZzZXQiOiAiNDMifQ==",
    "previous": null
  },
  "meta": {
    "limit": 50,
    "returned": 1,
    "has_more": true
  }
}
```

> Tip: schedule a nightly full sync plus an hourly delta run (see §2.4) so new providers appear quickly, while periodic full loads heal historical discrepancies.

---

## 2.3 Game Catalogue Import (`GET /games`)

1. Request `GET https://api.igsp.dev/v1/games` and paginate exactly like the provider endpoint: reuse the `cursor.next` token until exhausted. Include `updated_after` during incremental runs to limit payload size.  
2. Use `id` as the immutable primary key in your `games` table; the `provider_id` column links to the provider record you inserted in §2.2.  
3. Persist the following high-value attributes:
   - `slug`, `name`, `status`, `weight`, `categories[]` → drive lobby filtering and ordering.  
   - `rtp`, `bonus_rollover_coefficient` → expose to compliance teams and bonus engines.  
   - Embedded `provider` / `integration` objects → denormalise for quick lookups or keep as separate tables if you prefer strict normalisation.  
   - Lifecycle timestamps (`created_at`, `updated_at`, `deleted_at`) → power incremental updates and soft-delete handling.
4. When `deleted_at` is non-null, mark the game as disabled in your platform so it cannot be launched.

Example import snippet:

```bash
curl -s "https://api.igsp.dev/v1/games?limit=50&updated_after=${SINCE}" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "X-Timestamp: ${TIMESTAMP}" \
  -H "X-Signature: ${SIGNATURE}" | jq '{first: .data[0], cursor: .cursor.next}'
```

---

## 2.4 Incremental Updates & Scheduling

- Track the maximum `updated_at` processed per entity type and pass it back as `updated_after` to minimise payload size.  
- Persist the last seen `cursor.next` token; replay it after transient failures to resume where you left off.  
- Wrap the import in an idempotent transaction per page: upsert rows, then commit so replays do not duplicate data.  
- Alert when the API returns fewer records than expected (e.g., sudden drop in `meta.returned` with `has_more = false`) to catch surprise provider removals.

---

## 2.5 Validation Checklist

- **Schema drift**: Compare each response against the generated OpenAPI client models; reject unknown fields or type changes early.  
- **Referential integrity**: enforce foreign keys between `games.provider_id` and `providers.id`.  
- **Status parity**: ensure your platform reflects `status` and `deleted_at` flags inside 5 minutes to avoid launching blocked titles.  
- **Observability**: log request IDs, timestamps, cursor tokens, and `meta.returned` to trace issues with upstream availability.

---

# 🕹️ 3. Session Initiation & Game Launch

With provider metadata synced and signatures in place, the final step is to create a gameplay session for the selected title. The `POST /sessions` endpoint provisions launch context and hands back the definitive URL the player should be redirected to.

---

## 3.1 Launch Prerequisites

- Make sure the game exists and is enabled in your catalogue (`GET /games`).  
- Have a fresh player context ready: persistent `player_id`, wallet balance, language, and device preference.  
- Reuse the HMAC headers from Chapter 1 so the provider can authenticate the request.  
- Generate a platform-side `session_id` that is unique per launch attempt; reuse it if you need to retry the same session creation.

---

## 3.2 Request Schema Highlights

The request body mirrors the OpenAPI contract (`spec/igsp-providers.yaml#/paths/~1sessions/post/requestBody`):

| Field | Required | Notes |
|-------|----------|-------|
| `game_id` | ✅ | UUID returned by `/games`; determines the title being launched. |
| `player_id` | ✅ | Stable identifier used across wallet and compliance systems. |
| `player_name` | ✅ | Nickname surfaced inside the game HUD; keep profanity filtered. |
| `currency` | ✅ | ISO-4217 code; must match a value supported by the game/provider. |
| `session_id` | ✅ | Platform-issued unique reference, useful for auditing and callbacks. |
| `balance` | ✅ | Current player balance in the requested currency (float). |
| `device` | ❌ | `desktop` or `mobile`; defaults to `mobile` if omitted. |
| `return_url` | ❌ | Post-game redirect controlled by the platform. |
| `language` | ❌ | Recommended ISO-639-1 code (`en`, `de`, …). |
| `is_demo` | ❌ | Flag demo launches so the provider can bypass cashier hooks. |

---

## 3.3 Building the Session Request

Use the same header block as Chapter 1 and supply a JSON body that passes schema validation:

```http
POST https://api.provider.com/igsp/v1/sessions HTTP/1.1
Authorization: Bearer gp_live_a14f22...
X-Timestamp: 2025-10-17T12:03:41Z
X-Signature: 7b9a3d2c7f1c9e4a4df2a8d1a
Content-Type: application/json

{
  "game_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "player_id": "player-912",
  "player_name": "LuckyFox",
  "currency": "EUR",
  "session_id": "sess-20250101-0001",
  "balance": 100.00,
  "device": "desktop",
  "return_url": "https://casino.example.com/lobby",
  "language": "en",
  "is_demo": false
}
```

Provider-side validation includes HMAC verification, mandatory field checks, currency support, and business rules (e.g., minimum balance or restricted jurisdictions).

---

## 3.4 Handling the Provider Response

On success the provider returns `201 Created` with a single `url` property:

```http
HTTP/1.1 201 Created
Content-Type: application/json

{
  "url": "https://games.provider.com/session/launch/abc123"
}
```

- Immediately record the launch URL against the platform session for troubleshooting.  
- Redirect the player (HTTP 302 or client-side navigation) using this exact URL—do not attempt to alter query parameters.  
- Consider short-lived caching so a quick retry does not reissue the `POST /sessions` call unnecessarily.

---

## 3.5 Failure Paths & Retries

- **400 Bad Request**: schema violations, unsupported currency, or missing required fields. Inspect response details, fix, and retry with the same `session_id`.  
- **401/403**: signature or credential issues—regenerate the timestamp/signature and confirm keys.  
- **409 Conflict**: providers may reject duplicate `session_id` values if the previous launch has already progressed; generate a new ID.  
- **5xx**: transient upstream issues; implement exponential backoff and surface telemetry so operations teams can intervene.

Log every failure with the provider’s correlation headers (if present) and your `session_id` to speed up joint investigations.

---

## 3.6 Post-Launch Responsibilities

- Persist the session metadata (request + response) for reconciliation against later wallet callbacks.  
- Monitor provider callbacks/webhooks tied to the `session_id` so wallet debits/credits map cleanly.  
- Expire dormant sessions (no gameplay after a configurable timeout) and close the loop with the provider if required.

---

# 💳 4. In-Session Wallet Hooks

Once a player is live in a game session, the provider calls back into the platform to keep balances in sync. All wallet traffic flows through `POST /platforms/game-provider/hooks` and is distinguished by the `action` field. The platform must verify the HMAC signature (Chapter 1) and respond consistently so gameplay is uninterrupted.

Game providers submit four action types:
- `balance` — return the latest spendable balance for display in the game.
- `bet` — debit the player for a stake, tip, or freespin consumption.
- `win` — credit the player with a payout, jackpot, freespin result, or prize.
- `refund` — reverse a previous bet when the round is voided or corrected.

All payloads include the `player_id`, `currency`, and `session_id` you provided during session creation. Track `transaction_id` values to make each call idempotent.

---

## 4.1 Endpoint Contract Recap

- URL: `POST https://api.casino.com/webhooks/igsp/v1/platforms/game-provider/hooks` (adjust to your deployment).  
- Headers: reuse `Authorization`, `X-Timestamp`, and `X-Signature`.  
- `action` discriminator selects one of the JSON schemas defined in `spec/igsp-platforms.yaml`.  
- Successful responses return HTTP 200 with:
  - `balance` action → `BalanceResponse` containing the numeric `balance`.  
  - `bet`, `win`, `refund` actions → `TransactionResponse` with `balance` (post-transaction) and a platform-issued `transaction_id`.

Always respond within the provider’s timeout window (typically ≤2s); queue slow ledger work asynchronously if needed.

---

## 4.2 Balance Lookup (`action = balance`)

Used by the provider to render the current wallet value before taking further wagers.

```http
POST /platforms/game-provider/hooks HTTP/1.1
Authorization: Bearer gp_live_a14f22...
X-Timestamp: 2025-10-17T12:04:01Z
X-Signature: 5ce6e5e2b9f9417c1a68b6cab70f7e2a
Content-Type: application/json

{
  "action": "balance",
  "player_id": "player-912",
  "currency": "EUR",
  "session_id": "sess-20250101-0001"
}
```

**Platform response**

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "balance": 97.50
}
```

Return the spendable balance after accounting for any funds reserved for open rounds. If the session is unknown or suspended, respond with an error payload (HTTP 400/409) so the provider can halt gameplay.

---

## 4.3 Bet Debit (`action = bet`)

Debits a stake from the wallet. The `type` enum indicates whether it is a standard bet, tip, or freespin usage. Use `round_id` to group multi-part wagers and set `finished = true` when the round is closed.

```http
{
  "action": "bet",
  "player_id": "player-912",
  "currency": "EUR",
  "amount": 2.50,
  "game_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "transaction_id": "bet-20250101-000045",
  "session_id": "sess-20250101-0001",
  "type": "bet",
  "round_id": "round-18",
  "finished": false
}
```

**Platform response**

```http
{
  "balance": 95.00,
  "transaction_id": "plt-tx-845"
}
```

Hold the funds atomically, ensure idempotency by checking `transaction_id`, and return the post-debit balance alongside your own ledger reference.

---

## 4.4 Win Credit (`action = win`)

Credits a payout to the wallet. The `type` enum differentiates regular wins, jackpots, freespins, tournament rewards, and prizes. Use `round_id` to link the payout to the originating bet.

```http
{
  "action": "win",
  "player_id": "player-912",
  "currency": "EUR",
  "amount": 10.00,
  "game_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "transaction_id": "win-20250101-000045",
  "session_id": "sess-20250101-0001",
  "type": "win",
  "round_id": "round-18",
  "finished": true
}
```

**Platform response**

```http
{
  "balance": 105.00,
  "transaction_id": "plt-tx-846"
}
```

Ensure the credited amount is available immediately for subsequent bets in the same session. Duplicate `transaction_id` calls must be treated as retries and return the same accounting outcome.

---

## 4.5 Bet Refund (`action = refund`)

Reverses a previously accepted bet when a round is voided or an error occurs. Reference the original stake via `bet_transaction_id` and match the `type` enum (bet, tip, freespin) to the corrected wager category.

```http
{
  "action": "refund",
  "player_id": "player-912",
  "currency": "EUR",
  "amount": 2.50,
  "game_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "transaction_id": "refund-20250101-000045",
  "session_id": "sess-20250101-0001",
  "type": "bet",
  "bet_transaction_id": "bet-20250101-000045",
  "finished": true
}
```

**Platform response**

```http
{
  "balance": 107.50,
  "transaction_id": "plt-tx-847"
}
```

Mark the original bet as voided in your ledger to prevent duplicate refunds. If the referenced bet is unknown, return an error so the provider can flag the discrepancy.

---

## 4.6 Error Handling & Monitoring

- Return structured `ErrorResponse` bodies (HTTP 4xx/5xx) with stable error codes so providers can distinguish recoverable versus fatal issues.  
- Log `transaction_id`, `player_id`, `session_id`, and `action` for each request to support reconciliation.  
- Expose metrics (latency, failure rate) and alerts—wallet downtime directly impacts gameplay.  
- If you cannot process the hook within SLA, respond with a retriable 5xx rather than timing out silently.

By implementing these hooks, the platform guarantees that wallet balances stay authoritative while the provider focuses on real-time gameplay.

---
