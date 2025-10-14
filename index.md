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

## 🚀 Quick View

Below you can browse live interactive documentation for both APIs:

---

<div id="igsp-tabs">
  <style>
    #igsp-tabs { margin-top: 2em; }
    #tab-nav {
      display: flex; gap: 1.5em;
      background: #111827; padding: 1rem 1.5rem;
      border-radius: .5rem .5rem 0 0;
    }
    #tab-nav a {
      color: #f3f4f6; text-decoration: none; font-weight: 600;
    }
    #tab-nav a.active { color: #60a5fa; }
    #redoc-container {
      height: 80vh;
      border: 1px solid #e5e7eb;
      border-top: none;
      border-radius: 0 0 .5rem .5rem;
      background: #fff;
    }
  </style>

  <div id="tab-nav">
    <a href="#operators" id="tab-operators">Operators API</a>
    <a href="#providers" id="tab-providers">Providers API</a>
  </div>

  <div id="redoc-container"></div>

  <script src="https://cdn.redoc.ly/redoc/latest/bundles/redoc.standalone.js"></script>
  <script>
    const params = window.location.hash.replace('#','') || 'operators';
    const specUrl = params === 'providers'
      ? 'spec/igsp-providers.yaml'
      : 'spec/igsp-operators.yaml';
    document.getElementById(`tab-${params}`).classList.add('active');
    Redoc.init(specUrl, {
      scrollYOffset: 60,
      theme: { colors: { primary: { main: '#2563eb' } } }
    }, document.getElementById('redoc-container'));
    document.querySelectorAll('#tab-nav a').forEach(a => a.addEventListener('click', e => {
      e.preventDefault();
      location.hash = a.id.replace('tab-','');
      location.reload();
    }));
  </script>
</div>

---

## 🧩 License

Released under the **MIT License** — free for commercial and open-source use.