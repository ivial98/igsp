---
title: iGSP — iGaming Standard Protocol
nav_order: 1
---

# 🎮 iGSP — *iGaming Standard Protocol*

> **A universal open protocol connecting game providers and casino platforms.**

The **iGSP** defines an open, vendor-neutral API for standardized communication between iGaming platforms and game providers.

It introduces a unified set of endpoints covering games, sessions, providers, currencies, and countries — ensuring interoperability, compliance, and transparency across integrations.

---

## ✨ Key Principles

- **Open & neutral** — free to implement, modify, and extend.
- **Modular** — core specification with optional feature extensions.
- **Secure & auditable** — HMAC signatures, idempotency, and trace IDs.
- **Regulation-ready** — supports jurisdictional and KYC constraints.

---

## 📚 Repository Structure

| Path | Description |
|------|--------------|
| `/spec/igsp-reference.yaml` | OpenAPI 3.1 definition for the reference endpoints |
| `/spec/igsp-operators.yaml` | API for casino operators |
| `/spec/igsp-providers.yaml` | API for game providers |
| `/modules.md` | Overview of functional modules |
| `/changelog.md` | Version history and backward-compatibility notes |

---

## 🧭 API Documentation

| API | Description | Link |
|-----|--------------|------|
| Operators API | Endpoints for casino platforms | [View Operators API →]({{ "/operators.html" | relative_url }}) |
| Providers API | Endpoints for game providers | [View Providers API →]({{ "/providers.html" | relative_url }}) |

---

## 🧩 License

Released under the **MIT License** — free for commercial and open-source use.