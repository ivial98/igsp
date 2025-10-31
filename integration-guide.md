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
  "user_id": "u_901",
  "currency": "EUR",
  "game_id": "prov:bookofx"
}
```

**Provider validation:**
- recomputes HMAC using same secret  
- ensures request not older than 5 minutes  
- accepts or rejects based on signature

---

### ◀️ Game Provider → Casino Platform

```http
POST api.platform.com/webhooks/igsp/v1 HTTP/1.1
Authorization: Bearer gp_live_a14f22...
X-Timestamp: 2025-10-17T12:03:45Z
X-Signature: 13ac9f11c0d78fa...
Content-Type: application/json

{
  "user_id": "u_901",
  "bet_id": "b_845",
  "amount": 250,
  "currency": "EUR"
}
```

**Platform validation:**
- uses the same secret key  
- validates timestamp and HMAC  
- processes or rejects transaction

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

- The contract in `spec/igsp-providers.yaml` is the single source of truth for field names, formats, and pagination shape.  
- Generate a typed client (e.g., with OpenAPI Generator) or load the schema to auto-build validators so responses fail fast when the provider deploys breaking changes.  
- Reuse the HMAC credentials from Chapter 1: every import request must carry the same `Authorization`, `X-Timestamp`, and `X-Signature` headers.

---

## 2.2 Provider Synchronisation (`GET /providers`)

1. Call `GET https://api.igsp.dev/v1/providers` with the signed headers.  
2. Iterate through pages using the `links.next` URL until it becomes `null`. The surrounding `meta` block mirrors Laravel-style pagination and gives you `current_page`, `per_page`, and `total` for progress tracking.  
3. Upsert each provider by its canonical `id` (UUID). Recommended column mapping:
   - `name`, `slug` -> provider identity.  
   - `currencies[]`, `restricted_countries[]` -> regulate availability.  
   - `images[]` -> store alongside CDN URLs for launcher use.  
   - `min_age`, `min_kyc_level` -> enforce compliance at runtime.
4. Keep the raw JSON for auditing; it accelerates investigations when field semantics evolve.

> Tip: schedule a nightly full sync plus an hourly delta run (see §2.4) so new providers appear quickly, but you still heal historical discrepancies.

---

## 2.3 Game Catalogue Import (`GET /games`)

1. Request `GET https://api.igsp.dev/v1/games` and paginate exactly like the provider endpoint (`links` + `meta`).  
2. Use `id` as the immutable primary key in your `games` table; the `game_provider_id` column links to the provider record you inserted in §2.2.  
3. Persist the following high-value attributes:
   - `slug`, `name`, `status`, `weight`, `categories[]` → drive lobby filtering and ordering.  
   - `rtp`, `bonus_rollover_coefficient` → expose to compliance teams and bonus engines.  
   - Embedded `provider` / `integration` objects → denormalise for quick lookups or keep as separate tables if you prefer strict normalisation.  
   - Lifecycle timestamps (`created_at`, `updated_at`, `deleted_at`) → power incremental updates and soft-delete handling.
4. When `deleted_at` is non-null, mark the game as disabled in your platform so it cannot be launched.

Example import snippet:

```bash
curl -s https://api.igsp.dev/v1/games \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "X-Timestamp: ${TIMESTAMP}" \
  -H "X-Signature: ${SIGNATURE}" | jq '.data[0]'
```

---

## 2.4 Incremental Updates & Scheduling

- Capture the latest `updated_at` you processed for both providers and games. On subsequent runs, call the same endpoints with an `If-Modified-Since` header if supported by the provider, or filter locally by discarding unchanged rows.  
- Persist pagination cursors (last `links.next`) to recover gracefully if the job fails midway.  
- Wrap the import in an idempotent transaction per page: upsert rows, then commit so replays do not duplicate data.  
- Alert when the API returns fewer records than expected (`meta.total` drop) to catch surprise provider removals.

---

## 2.5 Validation Checklist

- **Schema drift**: Compare each response against the generated OpenAPI client models; reject unknown fields or type changes early.  
- **Referential integrity**: enforce foreign keys between `games.game_provider_id` and `providers.id`.  
- **Status parity**: ensure your platform reflects `status` and `deleted_at` flags inside 5 minutes to avoid launching blocked titles.  
- **Observability**: log request IDs, timestamps, and pagination metadata to trace issues with upstream availability.

---
