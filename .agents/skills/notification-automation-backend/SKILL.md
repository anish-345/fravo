---
name: notification-automation-backend
description: >-
  Specialized sub-agent for managing, debugging, and automating the Rust AI Notification Backend
  and OneSignal / Firebase push notification workflows for Fravo. Use when building, testing,
  monitoring, or adding triggers/endpoints to the notification backend.
---

# Fravo AI Notification & Backend Automation Sub-Agent

This skill equips the agent with complete end-to-end expertise over the **Rust AI Notification Backend (`notification-ai-backend/`)**, OneSignal REST API automation, UCB1 bandit optimization, and Fravo deep link delivery.

---

## 1. Quick Capabilities & Scope

1. **Rust Backend Operations:** Axum endpoints, Tokio background scheduler, SQLx migrations, and error handling.
2. **Push Notification Delivery:** OneSignal Free Tier REST API, Firebase Cloud Messaging (FCM v1), and device segmentation.
3. **Engagement Optimization:** UCB1 Multi-Armed Bandit variant selection, click/open rate scoring, and automated feedback loops.
4. **Behavioral Triggers:** Inactivity alerts, morning motivation, milestone celebrations, low-balance warnings, and referral viral boosts.
5. **Zero App Disruption:** No changes to the Fravo Flutter/Android app are required — all deep links and tags map directly to existing app listeners.

---

## 2. Directory Layout & Architecture

```
notification-ai-backend/
├── Cargo.toml            # Dependencies (Axum, SQLx, Tokio, Reqwest, Serde)
├── nixpacks.toml         # Deployment buildpack configuration
├── Dockerfile            # Container deployment configuration
├── src/
│   ├── main.rs           # Axum router setup & server entrypoint
│   ├── config.rs         # Environment variable loader
│   ├── db.rs             # SQLite connection pool, WAL mode & migrations
│   ├── errors.rs         # Application error types & HTTP status mapping
│   ├── handlers/         # API route handlers
│   │   ├── users.rs         # User registration & device tags
│   │   ├── messages.rs      # AI variant generation & next variant selector
│   │   ├── notifications.rs # Notification schedule, broadcast & send-test
│   │   ├── triggers.rs      # Behavioral automated trigger rules
│   │   ├── templates.rs     # Base fallback templates CRUD
│   │   ├── ab_tests.rs      # A/B testing management
│   │   ├── referrals.rs     # Referral reward notifications
│   │   ├── webhooks.rs      # OneSignal delivery & interaction webhooks
│   │   └── analytics.rs     # Dashboard analytics summary
│   ├── models/           # Struct definitions (User, Notification, Variant)
│   └── services/         # Core business logic
│       ├── ai.rs            # LLM prompt builder & fallback variant generator
│       ├── onesignal.rs     # OneSignal REST API client & payload builder
│       ├── firebase.rs      # FCM v1 sender & GA4 measurement protocol
│       ├── engagement.rs    # Adaptive scoring & UCB1 bandit algorithm
│       └── scheduler.rs     # Background cron scheduler (morning, evening, inactivity)
└── tests/
    └── api_tests.rs      # Integration test suite
```

---

## 3. Key Operational Playbooks

### Running the Backend Locally
```bash
cd notification-ai-backend
cargo run
```
Server starts on `http://localhost:8080` (or `PORT` from `.env`).

### Executing Tests & Diagnostics
```bash
cd notification-ai-backend
cargo test
cargo clippy -- -D warnings
```

### Sending a Live Test Notification
```bash
curl -X POST http://localhost:8080/api/notifications/send-test \
  -H "Content-Type: application/json" \
  -d '{
    "player_id": "<ONESIGNAL_PLAYER_ID_OR_EXTERNAL_ID>",
    "title": "Pippy needs you! 🐾",
    "body": "You have 15 minutes of screen time remaining today.",
    "target_url": "fravo://screen_time"
  }'
```

### Triggering an Automated Campaign Rule
```bash
# Available rules: morning_motivation, evening_summary, inactivity_alert, low_time_warning
curl -X POST http://localhost:8080/api/triggers/execute/morning_motivation
```

---

## 4. Known Gotchas & Prevention Protocols

1. **SQLite Database Locking:** Always ensure SQLx pool connects with WAL mode (`.journal_mode(SqliteJournalMode::Wal)`) and has a 10s busy timeout.
2. **Deep Link Scheme Mismatch:** All target URLs must use `fravo://` (e.g. `fravo://screen_time`, `fravo://stats`, `fravo://paywall`).
3. **OneSignal Empty Field Validation:** Never pass empty vectors `[]` for targeting fields in OneSignal payloads; leave them as `None` to be skipped by Serde.
4. **AI Generation Timeouts:** Wrap AI API calls in a 10-second timeout with immediate fallback to pre-seeded static templates in SQLite.
