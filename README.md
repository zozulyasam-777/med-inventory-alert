# 🚨 med-inventory-alert

**Self-hosted medical inventory monitoring system with automated shortage alerts and delivery forecasting**  
Built with **n8n**, **PostgreSQL**, and **Telegram** — no Google Sheets, no cloud dependencies. Ideal for offline or sanction-resilient environments.

> 💡 Perfect for clinics, pharmacies, or medical warehouses that need reliable, private, and automated stock control.

---

## 🌟 Features

- ✅ **Multi-warehouse support** — track stock across departments or locations  
- ✅ **Drug & package type catalog** — structured reference data  
- ✅ **Incoming/outgoing logs** (`stock_in`, `stock_out`) for full audit trail  
- ✅ **Shortage detection** based on configurable thresholds  
- ✅ **Delivery forecasting** (e.g., “Insulin will run out in 2.3 days”)  
- ✅ **Daily automated checks** via cron schedule  
- ✅ **Instant Telegram alerts** with drug, warehouse, and reason details  
- ✅ **100% self-hosted** — no external SaaS, no data leaks  
- ✅ **Docker-based deployment** — runs anywhere (Linux, Windows, macOS)

---

## 🏗️ Architecture
```mermaid
graph LR
  A[PostgreSQL] -->|Read stock data| B(n8n Workflow)
  B --> C{Is stock low or critical?}
  C -->|Yes| D[Send Telegram Alert]
  C -->|No| E[Do nothing]
  F[Cron Trigger] --> B


## 🌟 Quick Start
Prerequisites
Docker and Docker Compose (v2+)
1. Clone the repo
    git clone https://github.com/your-username/med-inventory-alert.git
    cd med-inventory-alert

2. (Optional) Adjust PostgreSQL port
    ports:
    - "5433:5432"  # host:container

3. Start services
    docker compose up -d

4. Access services
    n8n: http://localhost:5678
    → Set up owner account on first visit
    → Import workflow from med-inventory-alert-workflow.json
    Database: connect via DBeaver to localhost:5432 (or your custom port)
        DB: medinventory
        User: meduser
        Pass: medpass

5. Configure Telegram
    → Create a bot via @BotFather
    → Get your Chat ID (send a message to bot, then open https://api.telegram.org/bot<TOKEN>/getUpdates)
    → In n8n workflow → Telegram node → set chatId and select Telegram credential


---
📥 Workflows
This project includes three core workflows:

    → stock-import.json — daily CSV import (Mon–Fri at 01:00)
    → stock-sync.json — refresh stock cache from the latest snapshot (01:15)
    → stock-alert.json — shortage monitoring and Telegram alerts (08:00)
    → stock-chart.json — stock availability schedule and Telegram alerts (09:00)
👉 Import them via ☰ → Import in the n8n UI.
---
## 🏗️ Project Structure

med-inventory-alert/
├── docker-compose.yml          # Services: n8n + PostgreSQL
├── init-db.sql                 # DB schema + sample data
├── workflows/                  # ← new directory
│   ├── stock-import.json       # CSV import workflow
│   ├── stock-sync.json         # Stock cache sync
│   ├── stock-char.json         # Stock chart view 
│   └── stock-alert.json        # Telegram alerting
├── README.md
├── .gitignore
└── (auto-created on first run)
    ├── postgres-data/          # Persistent DB files (ignored)
    └── n8n-data/               # n8n credentials & workflows (ignored)


🔒 Privacy & Compliance
No external SaaS (Google, Airtable, etc.)
All data stays on your machine
Ideal for environments under sanctions or with strict data localization laws

📄 License
MIT License — feel free to use, modify, and deploy.
