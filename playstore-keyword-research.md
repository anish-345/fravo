# Fravo — Play Store Keyword Research

**Date:** Aug 12, 2026 · **App:** Fravo (walk to earn screen time) · **Package:** `avionti.fravo` · **Status:** Pre-launch / early (v1.0.0+7)

> **Data honesty note:** Google Play does NOT publish search volumes. No tool has real Play Store volume data — all platforms (AppTweak, Sensor Tower, Applyra, etc.) estimate from clickstream/autocomplete signals. Difficulty/traffic scores below are estimates based on the strength of apps currently ranking (ratings, recency, install velocity) and ASO-tool signals like Applyra (Easy ≤ 33, Medium 34–66, Hard ≥ 67). Treat them as relative rankings, not absolute numbers.

---

## 1. App context — what we're actually optimizing

| Dimension | Fravo |
|---|---|
| Core loop | Walk 1,000 steps → earn screen minutes (default 30, adjustable 5–60) for chosen apps |
| Enforcement | Apps hard-block when time runs out (native overlay + process kill) |
| Step tracking | Dual-mode: hardware pedometer (instant) + Health Connect (accurate, 5-min sync) |
| Privacy | 100% on-device, no account, no cloud — real differentiator in this category |
| Positioning | **Reward, not restriction** (your pitch angle) |
| Category to list under | **Productivity** (recommended — see §5) |
| Key permissions | Usage Access, Overlay, Accessibility, Activity Recognition, Health Connect |

**The strategic implication:** Fravo sits at the intersection of three search intents — (1) people hunting screen-time/app-blocking tools, (2) people looking for walking/step-reward apps, and (3) an **emerging niche that is literally "earn your screen time"**. That third cluster is where your whitespace is: it's the exact mechanic, it's young (most entrants launched 2025–26), and the leaders are new enough that a well-optimized newcomer can still enter.

---

## 2. Competitive landscape — the three clusters

### Cluster 1 — Direct mechanic competitors ("earn your screen time") ⭐ your real competition

| App | Mechanic | Traction signal | Listed as |
|---|---|---|---|
| **Unrot** (com.screentime.unrot) | Steps → coins → buy screen time | **56K ratings** in ~1 yr (2025-06) | "Unrot: Earn your Screen Time" |
| **DontRot** (com.dontrot.app) | Walk to unlock; 50/100/200 steps per minute | 19K+ users | "DontRot – Walk to Unlock Apps" |
| **PushUp Time** (com.pushscroll.pushuptime / workout.pushup.pushuptime) | AI push-ups/squats/planks → screen time | 266K users | "PushUp Time – App Blocker" |
| **RepsForReels** (com.repsforreels.app) | AI push-ups/squats → screen time | Newer | "RepsForReels: Earn Screen Time" |
| **Pushscroll: Exercise To Scroll** | Exercise to scroll | 16.7K ratings (2025-06) | — |
| **ScrollToll** | AI-verified exercise → time bank (max 2h) | New | "ScrollToll — AI Screen Time Blocker" |
| **touch grass: screen time limit** | Movement-based | 3K ratings (2025-03) | "touch grass: screen time limit" |

**What their titles tell us:** the niche itself converges on the phrases **"earn screen time"**, **"walk to unlock"**, **"exercise to scroll"**, **"steps to screen time"**. These are proven, convertible search strings — competitors put them in their *titles*, the highest-weight ASO field. Fravo's pure-walking mechanic (no camera, no AI pose detection) is a genuine angle: it's the most frictionless variant, and privacy is stronger (no camera at all).

### Cluster 2 — Classic screen-time / app-blocker incumbents (traffic but brutal difficulty)

| App | Traction | Notes |
|---|---|---|
| **AppBlock** | 15M+ downloads, 4.7 (200K reviews) | Category king on Android |
| **StayFree** | 4.6 (250K reviews) | Tracker + blocker |
| **ActionDash** | Well-established | Analytics-heavy |
| **ScreenZen** | 4.7 (25K reviews) | Friction approach |
| **one sec** | 4.6 (32K reviews) | Breathing pause, iOS-first |
| **Forest** | 10M+ | Gamified focus |
| **Opal / Freedom / Cold Turkey / BlockSite** | Paid, iOS/desktop-leaning | Less direct threat on Android |

**Implication:** head terms here ("app blocker", "screen time", "focus") are dominated by giants — per Applyra-style signals, "app blocker" is ~40 difficulty with traffic ~70, "block social media" ~38 difficulty, "focus" on Play is ~82 (very hard). A new app shouldn't burn its title slot on these yet.

### Cluster 3 — Walk-to-earn rewards apps (adjacent traffic, different intent)

| App | Traction |
|---|---|
| **Sweatcoin** | 4.4 (1.8M ratings on Play!) |
| **WeWard** | 20M users |
| **CashWalk / Winwalk / JUST** | Millions of installs combined |

**Implication:** "walk to earn" / "walk and earn rewards" is a *massive* search stream, but those users want money/gift cards, not screen time. Fravo can borrow the phrase ("walk to earn screen time" — already used by the niche) but shouldn't chase generic "walk to earn money" traffic — wrong intent, weak conversion.

---

## 3. Keyword clusters

Legend — **Demand**: relative search level (H/M/L). **Difficulty**: H = giants own it, M = winnable with effort, E = new app can realistically enter. **Fit**: relevance to Fravo.

### Cluster A — Core category: screen time & blocking (bread-and-butter)

| Keyword | Intent | Demand | Difficulty | Fit | Play |
|---|---|---|---|---|---|
| screen time | Browse | H | H | M | Long-term |
| screen time app | Browse/install | H | M | H | Short desc + long desc |
| screen time limiter | Action | M | M | H | Short desc + long desc |
| limit screen time | Action | M | M | H | Long desc |
| screen time control | Action | M | M | H | Long desc |
| screen time tracker | Browse | M | M | M | Long desc |
| app blocker | Action | H | M–H (~40) | H | Title candidate / long desc |
| block apps | Action | M | M | H | Long desc |
| block social media | Action | M | E–M (~38) | H | Long desc ⭐ |
| block instagram / block tiktok / block youtube | Action | M | E–M | H | Long desc ⭐ |
| app lock | Action | M | M | M | Long desc |
| focus app | Browse | H | H (~82) | M | Avoid now |
| digital detox | Browse | M | M | H | Long desc |
| phone addiction | Browse | M | M | H | Long desc |
| dopamine detox | Browse | M | E–M | H | Long desc ⭐ |

### Cluster B — Differentiator: earn-based / walk-to-earn (your whitespace)

| Keyword | Intent | Demand | Difficulty | Fit | Play |
|---|---|---|---|---|---|
| earn screen time | Action | M–H (growing) | E (niche is young) | **H** | **Title** ⭐⭐⭐ |
| walk to earn screen time | Action | M (growing) | E | **H** | **Title / short desc** ⭐⭐⭐ |
| walk to unlock apps | Action | M | E | **H** | **Title / short desc** ⭐⭐⭐ |
| steps to screen time | Action | L–M | E | **H** | Short desc ⭐⭐ |
| earn screen time by walking | Action | L–M | E | **H** | Long desc ⭐⭐ |
| walk to earn | Action | M | M (Sweatcoin owns intent) | M | Long desc |
| screen time rewards | Action | L | E | **H** | Long desc ⭐ |
| exercise to unlock apps | Action | M | E | M (you're walk-only) | Long desc |

### Cluster C — Fitness crossover (secondary traffic, real intent overlap)

| Keyword | Intent | Demand | Difficulty | Fit | Play |
|---|---|---|---|---|---|
| step counter | Browse | H | H (Leap Fitness etc.) | M | Long desc only |
| pedometer | Browse | H | H | M | Long desc only |
| step tracker | Browse | H | H | M | Long desc only |
| walking rewards | Browse | M | E–M | H | Long desc ⭐ |
| walk more | Browse | M | M | H | Long desc |
| fitness rewards | Browse | L–M | E | M | Long desc |

**Don't chase:** "step counter", "pedometer", "walk to earn money" as primary targets — intent mismatch and giants own them. Use them only as descriptive coverage in the long description.

### Cluster D — Problem/audience long-tails (easiest wins, best conversion)

| Keyword | Intent | Demand | Difficulty | Fit | Play |
|---|---|---|---|---|---|
| stop doomscrolling | Action | M | E | **H** | Short desc / long desc ⭐⭐ |
| stop scrolling | Action | M | E–M | **H** | Long desc ⭐ |
| break phone addiction | Action | M | E–M | **H** | Long desc ⭐ |
| reduce screen time | Action | M | M | **H** | Long desc |
| less screen time | Action | L–M | E | **H** | Long desc |
| digital wellbeing | Browse | M | M (Google term) | M | Long desc (avoid as title) |
| mindfulness phone | Browse | L | E | M | Long desc |
| study focus / study apps | Browse | H | H | M | Skip |

---

## 4. How Play Store ranking actually works here

- **Indexed fields (Play):** App title (**30 chars**, highest weight), short description (**80 chars**), long description (**4,000 chars**). Google reads the full long description, and applies **semantic matching** — related words and intent matter more than repeating a phrase.
- **Keyword density:** ~2–3% for your top 2–3 keywords in the long description is a sane target. Don't stuff — Google penalizes keyword stuffing on Play.
- **Ranking ≈ relevance × downloads × ratings.** As a new app, relevance (metadata) is the only lever you fully control at first; then reviews and install velocity feed in.
- **Reviews are a ranking factor** — plan review acquisition (in-app prompt) as part of launch.
- **Category choice matters:** Productivity is where screen-time/blocking apps live (AppBlock, StayFree, ActionDash). Health & Fitness is huge and saturated with step apps. **Recommend Productivity primary**; if Play Console lets you pick secondary (it doesn't — single category on Play), don't stress; the metadata does the work.

---

## 5. Recommended metadata draft (Play)

### Title (30 chars max) — lead with the differentiator phrase

Options, in order of my recommendation:

1. **`Fravo – Walk to Earn Screen Time`** (28) ⭐ recommended
2. `Fravo: Walk to Unlock Apps` (25)
3. `Fravo – Earn Screen Time by Walking` (31 → trim to `Fravo: Earn Screen Time` 23 + use "walk" in short desc)

**Why #1:** "walk to earn screen time" is simultaneously your niche's proven phrase, your mechanic in plain words, and semantically distinct from the blocker giants. "Screen time" at the end also catches partial-match on the big term.

### Short description (80 chars max)

> `Walk to earn screen time. 1,000 steps = 30 minutes on your apps. Stop doomscrolling — move more, unlock apps.` (108 — trim)

Trimmed candidate (~78):

> `Walk 1,000 steps = earn 30 min screen time. Stop doomscrolling, unlock apps by moving more.` (79 ✓)

- Hits: "walk", "earn screen time", "stop doomscrolling", "unlock apps", "screen time".
- Swap in "steps to screen time" if you prefer that phrasing.

### Long description skeleton (4,000 chars) — keyword map

Write ~700–900 words, structured with headers/bullets (Play parses them well). Place these phrases deliberately:

- **First 167 chars (visible before expand):** "Walk to earn screen time. Fravo turns your daily steps into minutes on your favorite apps — no willpower required."
- Headers: "Walk to earn screen time", "Block apps & stop doomscrolling", "Screen time limiter that rewards you", "Digital detox without restriction", "Private by design"
- Sprinkle (2–3% density, spread naturally): screen time, app blocker, block apps, limit screen time, stop doomscrolling, phone addiction, digital detox, steps to screen time, walk to unlock, walking rewards, dopamine detox, block instagram/tiktok/youtube, focus.
- Feature bullets from README: dual-mode step tracking (pedometer + Health Connect), 30-sec usage sync, midnight reset, custom package names, configurable rate 5–60 min/1,000 steps.
- End with privacy block: "All data stays on your device. No account. No cloud."

### Screenshot/keyword tie-in (conversion, not ranking)

- Frame 1 headline: "Stop the 11 p.m. scroll — walk to earn your screen time" (situation, not feature)
- Frame 2: the loop visual: 🚶 1,000 steps → ⏱ 30 min unlocked
- Frame 3: blocking proof: TikTok blocked, overlay shown
- Frame 4: privacy: "No account. No camera. On-device only" (direct jab at AI-camera competitors like PushUp Time)

---

## 6. Priority matrix — what to fight for now vs later

### Tier 1 — Attack now (low difficulty, high fit, in title/short desc)
- `earn screen time` · `walk to earn screen time` · `walk to unlock apps` · `steps to screen time`
- `stop doomscrolling` · `block social media` · `screen time app`

### Tier 2 — Build in first months (medium difficulty, in long desc; promote later)
- `app blocker` · `limit screen time` · `screen time limiter` · `screen time control`
- `block instagram` / `block tiktok` / `block youtube` · `phone addiction` · `digital detox` · `dopamine detox`

### Tier 3 — Long-term (giants own them; revisit after traction)
- `screen time` (head) · `focus` (~82 difficulty) · `step counter` / `pedometer` · `app lock`

### Never target
- Competitor brand names (Opal, AppBlock, Sweatcoin, Unrot) — trademark risk, wasted metadata.
- "Digital Wellbeing" as a title term — Google's product name, policy-gray.
- Medical/addiction-cure claims ("cure phone addiction", "ADHD treatment") — Play policy risk.

---

## 7. 30-day action plan

| Week | Action |
|---|---|
| 0–1 | Ship listing with Tier-1 metadata (§5). Set up **Applyra free** (1 app, 5 keywords) + **AppFollow** (free tier) tracking: earn screen time, walk to earn screen time, walk to unlock apps, steps to screen time, stop doomscrolling, block social media, screen time app. |
| 1–2 | Expand keyword list via **KeywordTool.io Play Store** (free autocomplete expansion) on seeds: "screen time", "walk", "earn", "block", "detox". Mine competitor listings (Unrot, DontRot, PushUp Time, touch grass) for gaps. |
| 2–3 | Launch **Play Console A/B experiments** on title + short description (2 variants each). Get first 50–100 installs from communities (r/Productivity, r/nosurf, r/digitalminimalism, Product Hunt) — install velocity feeds ranking. |
| 3–4 | Turn on **in-app review prompt** (non-blocking) — ratings are a ranking factor. Check Play Console **search analytics** (once live) for the terms you actually rank for; double down on top 11–50 positions. |
| Ongoing | Refresh listing every 4–6 weeks (update recency is a Play signal). Weekly rank check via Applyra/AppFollow. |

---

## 8. Compliance guardrails (this category is policy-sensitive)

- **Usage Access + Accessibility Service = elevated Play review risk.** Google scrutinizes apps using `PACKAGE_USAGE_STATS` and accessibility. Your privacy policy (already on-device, no data collection) is strong — make sure the *in-app* declaration matches the store listing, and answer Play's Data Safety form accurately (accessibility use, no data collection/sharing).
- **No health claims.** Don't imply Fravo "treats" addiction or is medical/ADHD therapy — competitors like RepsForReels flirt with this and risk takedowns.
- **No "Digital Wellbeing" / Google trademark in title.**
- **Screenshots must not overstate blocking** (e.g., don't claim it blocks system settings or is unbypassable — yours isn't and doesn't need to be).

---

## Sources
- Competitor listings (Google Play): Unrot, DontRot, PushUp Time, RepsForReels, ScrollToll, Sweatcoin, WeWard, CashWalk, Winwalk — fetched Aug 2026.
- Category analyses: cursedscreen.com, screentimeindex.com, wizroo.com, ditchthescroll.com, pullback.works (2026 roundups).
- ASO methodology: AppFollow Google Play ASO guide (2026), ASO Playbook screen-time post, Applyra keyword difficulty/traffic model (Easy ≤33 / Med 34–66 / Hard ≥67; "app blocker" ~40 dif, "block social media" ~38 dif, "focus" ~82 dif on Play).
- dev.to "I analyzed 204 screen-time apps" (Jul 2026) — niche traction data (Unrot 56K ratings, Pushscroll 16.7K, PushUp Time 11.5K, touch grass 3K).
