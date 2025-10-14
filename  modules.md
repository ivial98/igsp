---
title: API Modules
nav_order: 2
---

# API Modules

The iGSP standard defines several API groups:

| Module | Purpose |
|---------|----------|
| `/games` | Retrieve available games and metadata |
| `/sessions` | Create new gaming sessions |
| `/providers` | List available game providers |
| `/types` | Define game categories (Slots, Live, Crash, etc.) |
| `/currencies` | Supported currencies and precision |
| `/countries` | Jurisdictional rules and country configuration |

Each module is designed to be **independent and discoverable** through `/v1/` endpoints.

See the [OpenAPI spec](spec/igsp-reference.yaml) for full details.