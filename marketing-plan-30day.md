# Fravo — 30-Day No-Budget Marketing Plan (500 installs, Month 1)

**Goal:** ~500 installs in the first 30 days. **Budget:** ₹0 / $0. **All** effort goes into organic channels + product hooks.
**Builds on:** `playstore-keyword-research.md` · `playstore-listing-draft.md` (both in repo root)

> **Reality check first:** 500/month for a fresh, no-brand app is a *stretch goal*, not a guarantee — but it's genuinely in range for this category. The "earn your screen time" niche grew entirely on TikTok/Reddit (Unrot: 56K ratings in ~1yr, PushUp Time: 266K users). Your mechanic is *demonstrable on video* — that's the unlock. The plan below is engineered for a **~200-install launch spike** (Product Hunt + Reddit + posting blast) plus a **~10/day compounding engine** (content + communities + ASO velocity). Spike + engine = 500.

---

## 1. The one big idea: the product IS the content

No budget means content is your only paid-in-attention media. Fravo's mechanic is a ready-made story hook:

> "I built an app that blocks TikTok until you walk 1,000 steps. Your body is the password."

That single sentence works on TikTok, Reels, Shorts, X, Reddit, Hacker News, Product Hunt, and every "I built this" community. **Every video, post, and screenshot you publish should show the app working, not talk about it.** The block overlay + steps→minutes ticker is inherently visual.

**Your content formula:** hook (the absurd-but-true mechanic) → 5-second demo → payoff (steps climbed / app unlocked / scroll guilt-free) → CTA.

**Personas to target (one message each):**

| Persona | Hook | Channel |
|---|---|---|
| **The doom-scroller** (ADHD-ish, knows they over-scroll) | "Stop doomscrolling — literally can't until you walk" | TikTok, Reddit r/nosurf, r/ADHD |
| **The fitness-motivation seeker** | "Turn screen time into workout motivation" | r/walking, r/DecidingToBeBetter, fitness TikTok |
| **The indie/tech bro** | "I built this — here's the stack" | X, HN, r/SideProject |

---

## 2. Channel matrix — where the 500 comes from

| Channel | Est. month-1 yield | Effort | Priority |
|---|---|---|---|
| **TikTok / Reels / Shorts** (3–5 demo clips, 1–2 might pop) | 50–200 (high variance) | Medium | ⭐⭐⭐ |
| **Play Store open beta + ASO velocity** | 60–120 (compounds weekly) | Low ongoing | ⭐⭐⭐ |
| **Product Hunt launch** (one day, big spike) | 30–80 | High, one-time | ⭐⭐⭐ |
| **Reddit** (4–6 genuine posts across subs) | 50–120 | Medium | ⭐⭐ |
| **X build-in-public** | 20–60 (warm, feedback-rich) | Low | ⭐⭐ |
| **Hacker News Show HN** | 10–50 | Low | ⭐⭐ |
| **Blogs/directories/curation** (15 outreach emails) | 30–80 (delayed, compounds) | Low | ⭐⭐ |
| **In-app referral hook** (ship in week 2) | 20–50 | Product work | ⭐ |
| **Landing page** (converts social traffic) | multiplier, not source | Build once | ⭐⭐⭐ |

**Honest number:** spike 150–250 + engine 8–15/day × 25 days ≈ **380–620**. Yes, 500 is the right target to aim at.

---

## 3. Week 0 — Pre-launch build list (do this before anything else)

- [ ] **Landing page** (replace privacy-only Netlify site): one screen — hero demo GIF, "Get it on Google Play" button, 3 feature bullets, review stars later, privacy badge ("No account. No camera. On-device only"). Keep `/privacy` link. *(I can build this — Flutter web or plain HTML, deploy to your existing Netlify setup.)*
- [ ] **Play Console:** finish listing per `playstore-listing-draft.md`, submit for **closed → open testing** first. Open beta = the app is indexable + downloadable instantly, and you can collect real installs + reviews *before* full production launch. Flip to production when stable.
- [ ] **3 demo videos** (phone-screen capture, 15–25s each):
  1. Hero: select TikTok/Instagram → walk counter → overlay blocks → balance unlocks. Caption: "your body is the password"
  2. Feature: adjust reward rate (15/30/45 min per 1k steps)
  3. Stats: screen time down, steps up, "7 day streak"
- [ ] **Handles reserved:** tiktok.com/@getfravo, x.com/getfravo (or @fravoapp), YouTube, Instagram.
- [ ] **Asset kit:** 3:4 portrait versions of all clips (TikTok/Reels), 1:1 + 16:9 crops, 3 screenshots with the copy from the listing draft.
- [ ] **Founder story, one paragraph:** why you built it (your own doomscrolling/fitness angle), the stack (Flutter → Android), the privacy stance. Reuse everywhere.
- [ ] **Waitlist or not?** Recommendation: skip waitlist, launch fast. A 2-week waitlist delays your spike for maybe 50 emails. Ship.

---

## 4. Launch week — day-by-day

**Launch on a Tuesday (PT).** Product Hunt runs Tue–Thu best; Reddit is most active Tue–Wed.

| Day | Action |
|---|---|
| **Mon** | Polish listing live on open testing. Confirm all videos/screenshots ready. Prep posts (drafts approved). |
| **Tue 12:01am PT** | **Product Hunt launch.** Title: "Fravo – Walk to Earn Screen Time". Tagline: *"TikTok stays blocked until you walk 1,000 steps."* First comment: founder story + demo video + roadmap. Reply to every comment the first 12 hours. |
| **Tue** | **X thread** (5–7 tweets): the build story with clips, tag #buildinpublic #indiehackers. Crosspost demo #1 on TikTok with #walktoearn #screenTime #doomscroll challenge frame. |
| **Wed** | **Show HN:** title "*Show HN: I made an app that blocks TikTok until you walk 1,000 steps*". Lead with the demo GIF, invite technical questions (Flutter, pedometer, Health Connect, accessibility blocking). |
| **Thu** | **Reddit post #1** — r/AndroidApps (build-in-public friendly) + r/SideProject. Share the story, ask for feedback. |
| **Fri** | **Reddit post #2** — r/nosurf or r/digitalminimalism with *genuine* framing (see §5 rules). Demo clip #2 out. |
| **Sat–Sun** | Engage on everything (PH replies, HN comments, TikTok replies). Clip #3 (stats/streak). Answer every comment as the maker. |

**Launch-week spike target: 150–250 installs.**

---

## 5. Reddit playbook (the 4–6 posts that matter)

**Rules that protect your account:** most self-promo-adjacent subs ban link-dumping. Never post a bare link. Always: story + value + link in comments, and *participate in the sub genuinely for a few days before/after*.

| Subreddit | Angle | Format |
|---|---|---|
| r/AndroidApps | "I built a walk-to-earn screen time app — happy to take feedback" | Text + demo clip, link in comment |
| r/SideProject | Build story, tech details (Flutter, dual-mode step tracking) | Text + clip |
| r/nosurf | Solve-the-problem framing: "Willpower blockers fail — what if the app physically locked apps behind steps?" | Discussion + solution mention (check sub rules for self-promo) |
| r/ADHD | External accountability angle (ADHD users love this mechanic) | Text, link in comment |
| r/walking or r/DecidingToBeBetter | Fitness motivation angle: "turn screen time into walking motivation" | Text + stats clip |
| r/getdisciplined | Discipline-machinery angle | Light touch |

**The post template:**
- Title: specific + human. *"Instead of a screen time timer I can ignore, I built one that locks my apps until I walk 1,000 steps"*
- Body: the problem → why timers fail → what you built (2 lines) → the privacy stance → invite feedback. Link in comments. No begging for installs.
- Reply to every comment within 24h. Ask "what would make you use this daily?"

---

## 6. TikTok / Reels / Shorts — script pack (3 clips, 1/week min)

Format: 15–25s, hook in first 1.5s, captions on (most watch muted), trending audio optional.

1. **"The Deal"** — VO/text: "TikTok: blocked. Instagram: blocked. YouTube: blocked. Until you walk 1,000 steps → [block overlay → steps ticker → unlocked]. My body is the password now." CTA: "app: Fravo (link in bio)"
2. **"POV: you tried to open Instagram at 9am"** — overlay pops, you actually walk away, come back, balance unlocked. Comedy beats.
3. **"30 days with Fravo"** — before/after stats: screen time −2.1h/day, +64k steps, "I touched grass 4 times this week 🌱".

Post 2–3×/week at minimum; consistency beats polish here. **Reply to every comment** — comments drive the algorithm harder than likes.
**Hashtag set:** #walktoearn #screentime #doomscrolling #digitaldetox #appblocker #fitnessmotivation #adhd #indiedeveloper

---

## 7. X / build-in-public (low effort, high feedback value)

- 5–7 tweet thread at launch (story → demo → stack → privacy → "what would you add?").
- Then 2–3 posts/week: small wins ("blocked my 40th scroll attempt today", usage stats, next feature). Screenshots > words.
- Engage daily-ish with #buildinpublic, #indiehackers, #nosurf chatter — genuine comments, not spam.
- DM screenshot-ready: share clips with creators who post about screen time/ADHD (no pitch-first DMs — reply to their posts with value).

---

## 8. Product Hunt + HN specifics

**Product Hunt:** use your real story. Gallery = screenshots with the listing copy. Maker comment: story + what makes it different vs AppBlock/Opal (reward, not restriction) vs PushUp Time (no camera needed — walking only, private). Ask PH comments focused: "What would make this your daily driver?" Launch day engagement > votes for visibility.
**HN:** Show HN with demo GIF at top. Expect hard questions — pedometer battery, Health Connect accuracy, how enforcement works on Android (accessibility + overlay), bypassability. Answer honestly; "how did you do X" threads are free marketing. Avoid the words "addiction cure / ADHD fix" (both here and everywhere — Play policy).

---

## 9. Free blogs, directories & newsletters (30–80 installs, compounding)

Send ~15 short, personal emails with: 1-line pitch, demo link, Play Store link, "happy to answer questions / provide screenshots". Targets:

- Review/directory sites actively covering this category: **cursedscreen.com, screentimeindex.com, ditchthescroll.com, pullback.works, wizroo.com** (all published "best app blockers 2026" lists — ask to be added/compared; they want fresh entries)
- Android app newsletters: **Play Store Finds, Android App of the Day, Apps for Android**, r/android weekly threads
- Free app directories: **AppBrain (register app), AlternativeTo (add listing), Product Hunt alternatives, F-droid? (no — requires open source), AppAgg**
- Tech press angle is weak for a solo app — skip cold-pitching AndroidPolice; directionality: indie-friendly sites only, no budget.

---

## 10. In-app growth hooks — ship these in weeks 1–2 (cheap in Flutter, big payoffs)

1. **Shareable stat card** — "Walked 12,400 steps → earned 6h12m screen time" with Fravo branding, one-tap share to IG story/TikTok/X. User shares = your ads.
2. **Referral bonus** — invite a friend (share link/code) → both get **+10 min screen time** (credit into the existing time bank — your reward currency makes this native). Real-user referrals avoid Play's incentivized-install problems since reward is in-app time, not payment. Verify referral only fires on real new installs.
3. **Streak + milestone share** — on 7-day streak, "Blocked 132 scroll attempts" cards (the funny numbers are the viral ones).
4. **In-app review prompt** (non-blocking, after day-3 positive session) — reviews feed Play ranking directly.
5. Set a **goal prompt** on day 2 push: "You walked 2k steps today — that's 1h of scroll. Nice." (re-engagement = retention = better Play signals)

---

## 11. Metrics & weekly review (every Sunday, 20 minutes)

| Metric | Target (end of each week) |
|---|---|
| Installs (Play Console) | W1: 200 · W2: 300 · W3: 400 · W4: 500 |
| Activation rate (installed → set up blocking → walked ≥1k steps) | ≥ 40% |
| Play Store reviews | ≥ 20 by day 30 |
| Play Store search impressions | growing week over week (listing + velocity feed this) |
| Source breakdown | know which channel is #1, double on it |

**Kill rule:** any channel at 0 installs after 2 weeks of effort → stop, redirect time to the winner. **Double rule:** whichever channel over-performs in week 1–2 gets 2× the content next week.

---

## 12. Risks & guardrails

- **Play review rejection (biggest risk):** Usage Access + Accessibility = elevated scrutiny. If rejected/restricted: fix per feedback, re-submit; keep open beta running meanwhile. Never fake installs or use incentivized download networks — Play detects and *removes* with no appeal.
- **Subreddit bans:** read each sub's rules before posting; link-in-comment, participate genuinely. One ban ≠ crisis, two = change approach.
- **TikTok variance:** clip #1 flopping means nothing — plan 5 clips, algorithm is a lottery with good odds.
- **Don't over-promise:** no "cures phone addiction", no medical claims (policy + trust).
- **Apple later:** iOS version = whole second market using the same content engine (One Sec-proven tactic). Not in month-1 scope — note for later.

---

## 13. The 30-day rhythm, one glance

| Week | Focus | Target installs |
|---|---|---|
| **W0** | Build: landing page, listing live (open beta), 3 videos, handles, assets | — |
| **W1** | LAUNCH: PH + X + HN + Reddit ×2 + clips 1–2 | 200 |
| **W2** | Engine: clips 3+, Reddit ×2, outreach emails sent, referral hook ships, review prompt live | 300 |
| **W3** | Content drip + community engagement + blog responses; first Play Console data → ASO tweak (A/B title/short desc) | 400 |
| **W4** | Double the winning channel; stats-share push; launch recap + "month 2 plan"; flip open beta → production | 500 |

**Month 2 preview (if month 1 hits 400+):** second content format (walk-with-me / POV), iOS build start, bigger review-site push, maybe first paid test (₹500–1,000 a day on one winning keyword) — but only from real revenue or if you choose to invest. Month 1 stays strictly zero-budget.