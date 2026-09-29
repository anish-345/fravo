# Universal Guidelines: Rust Backend Architecture, Notifications & Learnings

These rules define strict engineering standards, architectural decisions, and error prevention protocols for the **Rust AI Notification Backend (`notification-ai-backend/`)**.

---

## 1. Core Architecture & Stack Invariants

* **Runtime:** Tokio async runtime (`tokio = { version = "1.0", features = ["full"] }`).
* **Web Framework:** Axum (`axum = "0.7"`, with `tower-http` CORS and tracing).
* **Database Layer:** SQLx with SQLite (`fravo_notifications.db`) in local/container dev and PostgreSQL compatibility.
* **Notification Channels:** OneSignal Free Tier REST API + Firebase FCM v1 fallback.
* **AI Engine:** Primary LLM client (Agnes AI / OpenAI / Claude) generating multi-armed bandit (UCB1) notification variants.

---

## 2. Critical Rust Learnings & Error Countermeasures

### A. Database Concurrency & File Lock Prevention (SQLite)
* **Problem:** SQLite `database is locked` / `busy` error when multiple async Tokio tasks write concurrently.
* **Prevention:**
  1. Always configure WAL mode: `.journal_mode(SqliteJournalMode::Wal)`.
  2. Set a busy timeout on the pool: `.busy_timeout(std::time::Duration::from_secs(10))`.
  3. Ensure write probe fallback exists so read-only Docker/Nixpacks container paths fallback safely to `/tmp/`.
  4. Always enable foreign keys: `.pragma("foreign_keys", "ON")`.

### B. Serde Deserialization & Optional Field Safety
* **Problem:** `422 Unprocessable Entity` or silent request drops in Axum when incoming JSON is missing optional fields or has unexpected null values.
* **Prevention:**
  1. All optional fields in request models MUST be wrapped in `Option<T>` with `#[serde(default)]` and `#[serde(skip_serializing_if = "Option::is_none")]`.
  2. For enum deserialization, always provide a fallback or `#[serde(rename_all = "snake_case")]` to avoid casing mismatches between Dart/Web and Rust.

### C. OneSignal REST API Payload Guardrails
* **Problem:** OneSignal HTTP 400 when sending notifications due to mutually exclusive targeting parameters or empty arrays.
* **Prevention:**
  1. Never send empty vectors for `include_player_ids`, `included_segments`, or `include_aliases`. If empty, serialize as `None` (omitted from JSON payload).
  2. Always use `headings: {"en": "..."}` and `contents: {"en": "..."}` maps (never raw strings).
  3. Always populate `data` with deep link target URLs (e.g., `{"target_url": "fravo://screen_time"}`) and message variant IDs for engagement attribution.
  4. Use `Authorization: Key <REST_API_KEY>` or `Basic <REST_API_KEY>` according to OneSignal v1 requirements.

### D. Blocking Code Inside Tokio Async Contexts
* **Problem:** Tokio worker threads stalling when running synchronous file I/O or heavy computation.
* **Prevention:**
  1. Never use `std::thread::sleep` in async handlers — use `tokio::time::sleep`.
  2. Use `tokio::fs` for file operations or `tokio::task::spawn_blocking` for CPU-heavy tasks.

### E. AI Fallback & Multi-Armed Bandit (UCB1) Scoring
* **Problem:** AI provider downtime causing notification dispatch failure or zero variation.
* **Prevention:**
  1. Always maintain pre-seeded fallback templates in SQLite for each trigger category (morning, inactivity, streak, milestone, low screen time).
  2. Recalculate variant score on every webhook event using:
     $$\text{Score} = (0.3 \times \text{open\_rate}) + (0.4 \times \text{click\_rate}) + (0.3 \times \text{conversion\_rate}) - (0.1 \times \text{dismissal\_rate})$$
  3. When choosing next variant, use UCB1 exploration-exploitation balance:
     $$\text{UCB1} = \bar{X}_i + \sqrt{\frac{2 \ln N}{n_i}}$$

---

## 3. Standard Verification Commands

Before concluding any Rust backend change:
```bash
cd notification-ai-backend
cargo check
cargo clippy -- -D warnings
cargo test
```
