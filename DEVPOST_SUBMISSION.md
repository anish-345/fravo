# RevenueCat Shipaton 2026 — Devpost Submission Guide for Fravo

## App Overview
- **App Name**: Fravo — Walk to Earn Screen Time
- **Tagline**: The gamified wellness app where movement unlocks your digital life.
- **Platform**: Flutter (Android & iOS) with Rust Axum AI Notification Backend
- **Repository**: Open Source (MIT Licensed)
  - Flutter Mobile App: [https://github.com/anish-345/fravo](https://github.com/anish-345/fravo)
  - AI Backend Engine: [https://github.com/anish-345/fravoau](https://github.com/anish-345/fravoau)
- **Judge Access Code**: Provide your personal referral code (e.g. `FRAVO-XXXXX`) in the Referral / Promo card to instantly unlock 7 Days of Free Fravo Premium directly on the live Google Play Store version!

---

## Targeted Prize Tracks & Winning Strategy

### 1. 🏆 Next Gen Award ($20,000) — Primary Focus
- **Category Focus**: Outstanding app built by a student creator.
- **Why Fravo Wins**:
  - Solves a massive student & Gen-Z problem: doomscrolling and digital addiction.
  - Integrates RevenueCat Paywalls & Subscriptions with flexible monthly/annual plans and viral referral-driven 7-day trials.
  - Features Pippy the interactive AI companion who evolves as you walk.

### 2. 🏆 OneSignal "Keep Them Coming Back" Award ($25,000) — Co-Primary Focus
- **Category Focus**: Best push notification experience driving re-engagement and retention.
- **Why Fravo Wins**:
  - **Automated Daily Sync**: Syncs 290+ player tags (`primary_distraction`, `companion_personality`, `user_goal`, `current_streak`, `behavior_state`) directly from OneSignal into SQLite.
  - **Real Reinforcement Learning (UCB1 Multi-Armed Bandit)**: Notification variants compete based on live webhook engagement scores (opens, clicks, conversions, dismissals). High-converting copy is exploited; under-tested AI copy is explored.
  - **Hyper-Personalized Content**: Push messages adapt dynamically to the user's companion persona (*Tough Love*, *Friendly Motivator*, *Stoic Guide*, *Chill Sloth*) and mention their actual distraction app (*Instagram*, *YouTube*, *TikTok*).
  - **Rich Action Buttons**: Push notifications include interactive buttons ("Walk 5 Min", "Bank Time", "Snooze") with custom deep linking (`fravo://screen_time`, `fravo://stats`, `fravo://paywall`).

### 3. 🏆 HAMM Award ($50,000) & Best Design ($10,000)
- **Monetization**: Seamless RevenueCat integration offering 2x reward rates, unlimited app blocking, and zero ad interruptions.
- **Visual Excellence**: Neumorphic/glassmorphic design system, Pippy emotional pet animations, and custom Home Screen Android AppWidget.

---

## Devpost Submission Form Template

### Project Title
**Fravo — Walk to Earn Screen Time**

### Elevator Pitch (140 characters)
*Turn doomscrolling into movement. Fravo locks your distraction apps until you walk, powered by RevenueCat monetization & an AI bandit notification loop.*

### About the Project / Inspiration
Students and professionals lose 4 to 6 hours every day to mindless social media scrolling. Traditional screen time limiters rely on willpower, friction, or guilt — and users quickly disable them.

We asked: *What if screen time wasn't forbidden, but earned through healthy physical activity?*
Fravo introduces a simple, dopamine-aligned habit loop: **1,000 steps walked = 30 minutes of unlocked screen time**. You move your body, you bank time, and your favorite apps remain locked until you earn them.

### What it Does
1. **Accessibility-Level App Blocker**: Monitors and temporarily blocks distracting apps (Instagram, YouTube, TikTok, Reddit) once your banked screen time depletes.
2. **Step Bank Engine**: Directly connects to pedometer sensors. Walking replenishes your screen time bank.
3. **Pippy the Companion**: An animated, evolving digital pet that reflects your activity. Set Pippy's personality to *Tough Love*, *Friendly Motivator*, *Stoic Guide*, or *Chill Sloth*.
4. **RevenueCat Pro Subscriptions**:
   - Free Tier: Block up to 3 apps, standard reward rate (1k steps = 30 min).
   - Fravo Pro: Unlimited app blocking, 2x reward rate (1k steps = 60 min), emergency passes, and advanced screen-time analytics.
   - Built-in 7-day viral referral trial system managed via RevenueCat.
5. **AI-Powered Multi-Armed Bandit Notification System (OneSignal + Rust Backend)**:
   - Pulls daily user tags from OneSignal.
   - Generates and tests push variants using Agnes AI.
   - Optimizes message CTR using Upper Confidence Bound (UCB1) reinforcement learning.

### How We Built It
- **Mobile Frontend**: Flutter 3.x with custom animations, Flutter Riverpod / Provider architecture, and Hive local storage.
- **Native Android & Kotlin**: Custom `AccessibilityService` for robust app blocking, plus native Kotlin `AppWidgetProvider` for home screen step/time banking.
- **Monetization**: RevenueCat SDK (`purchases_flutter`) for paywalls, subscription entitlements, and 7-day referral trials.
- **Notification AI Backend**: High-performance Rust (Axum, SQLx, Tokio) backend deployed on Belmo cloud.
  - Multi-Armed Bandit (UCB1) reinforcement algorithm scoring open, click, conversion, and dismissal webhooks.
  - Daily automatic sync from OneSignal API.
  - AI copy generation with Agnes AI and multi-model fallback chain.

### Challenges We Ran Into
- Balancing aggressive Android background battery optimizations with real-time step counting.
- Engineering a low-latency app blocker that feels snappy without draining device resources.
- Constructing a mathematically sound Multi-Armed Bandit algorithm in Rust that balances exploration of new copy with exploitation of proven high-converting variants.

### Accomplishments We're Proud Of
- 15/15 unit and widget tests passing with 0 lint errors across the entire Flutter codebase.
- Over 290 real registered test users and devices synchronized through OneSignal.
- 100% functional RevenueCat paywall and judge promo code redemption system.

### What We Learned
- How to structure mobile subscription paywalls to optimize for user psychology rather than friction.
- How push notification copy reinforcement loops dramatically outperform static scheduled campaigns.

### What's Next for Fravo
- Multi-device family/friend step challenges with shared screen time pools.
- Wear OS and Apple Watch companion app.
- Expanded companion evolutions and accessory shop unlocked by streak milestones.

---

## Judge Testing Credentials & Instructions
1. Download **Fravo** directly from the Google Play Store: [https://play.google.com/store/apps/details?id=avionti.fravo](https://play.google.com/store/apps/details?id=avionti.fravo) (or clone and run the open-source repo).
2. Complete the quick 3-step onboarding.
3. On the Home Dashboard, scroll down and tap the **Invite Friends / Redeem Code** card.
4. Enter the creator referral code `[INSERT_YOUR_CODE_HERE, e.g. FRAVO-XXXXX]` and tap **Claim 7 Days Pro**.
5. Your account immediately unlocks **Fravo Pro (7-Day Trial)** with unlimited app blocking, 2x reward rate, and zero ads!
