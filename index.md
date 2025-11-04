---
title: iGSP — iGaming Standard Protocol
nav_order: 1
---

# 🎮 iGSP — *iGaming Standard Protocol*

> **A universal open protocol connecting game providers and casino platforms.**

In the iGaming industry, **game providers** are interested in being available across as many casino platforms as possible, while **casino platforms** aim to offer their players a wide variety of games to build a unique mix that matches their audience.  

However, differences in API structures and approaches between platforms and providers make each integration unique and often complex. One side is usually forced to develop a custom integration layer to handle authentication, sessions, bets, and reporting.  

Building and testing these layers consumes time and developer resources — increasing the cost and duration of integrations.

The **iGSP standard** aims to solve this by defining a common API structure for both **game providers** and **casino platforms**. By implementing this protocol, both sides expand their partnership potential — and the technical integration process is reduced to a simple exchange of API keys.

---

## ✨ Key Principles

- **Open & neutral** — free to implement, modify, and extend.
- **Secure & auditable** — HMAC signatures, idempotency, and trace IDs.
- **Regulation-ready** — supports jurisdictional and KYC constraints.

---

## 📚 Repository Structure

| Path | Description |
|------|--------------|
| `/spec/igsp-platforms.yaml` | API for casino platforms |
| `/spec/igsp-providers.yaml` | API for game providers |
| `/changelog.md` | Version history and backward-compatibility notes |

---

## 🧭 API Documentation

| API | Description | Link |
|-----|--------------|------|
| Platforms API | Endpoints for casino platforms | [View Platforms API →]({{ "/platforms.html" | relative_url }}) |
| Providers API | Endpoints for game providers | [View Providers API →]({{ "/providers.html" | relative_url }}) |

---

## 🧩 License

Released under the **MIT License** — free for commercial and open-source use.
