# Fravo — Submission Resources: Indus Appstore + Softonic

**Date:** 2026-08-12 · **App:** Fravo (Walk to Earn Screen Time) · **Companion doc:** `ASO_KEYWORDS.md` (Google Play)

---

## ⚠️ Shipaton note first

Both stores are **extra distribution, not eligibility** — Shipaton 2026 counts App Store / Google Play / Samsung Galaxy Store only. Also keep version parity: publish to **Google Play first** (or the same day) so the "first public release in the Aug 1 – Sep 30 window" attribution stays clean, then push the same build here.

---

# A. INDUS APPSTORE (India-first Android store — PhonePe)

**Why bother:** Zero listing fee for year 1, **0% commission on in-app purchases**, Indian vernacular reach (12 languages), and it ranks on "Made in India" / Aatmanirbhar searches. Strong tier-2/3 reach; also a good #BuildInPublic talking point for the Shipaton ("shipped on India's own app store").

**Portal:** https://developer.indusappstore.com/

## A.1 Account setup checklist
- [ ] Register (Individual / Organization) — name, email, address
- [ ] Verify email + mobile (OTP)
- [ ] Identity verification: **PAN / Voter ID / Driving Licence** + proof of address (keep a scanned copy ready)
- [ ] No fee for first year; nominal annual fee signalled after that
- [ ] Payment: no Apple/Play-style commission; you can plug your own gateway later (UPI-ready market). For now list **Free** — Fravo's Shopaton monetization runs through Google Play Billing + RevenueCat.

## A.2 App submission checklist
- [ ] **File:** signed release **APK, AAB or APKS** (JKS keystore accepted). Build: `flutter build appbundle --release` / `flutter build apk --release`.
- [ ] **Title** (keep clear + accurate — Indus rejects unclear metadata)
- [ ] **Short description** (they explicitly want short & straightforward)
- [ ] **Long description** (see copy below — concise, positive, no review-style claims)
- [ ] **Icon** (reuse 1024×1024 launcher icon)
- [ ] **Screenshots** (3–8, phone format, show real screens — same set as Play)
- [ ] **Category:** Health & Fitness (steps + wellbeing) or Lifestyle — pick in console
- [ ] **Content rating / target group:** Everyone / General
- [ ] **Localization:** 12 Indian languages — use Auto Translate, then hand-fix Hindi (sample below). Hinglish (Hindi in Roman script) performs well in India — include where the form allows.
- [ ] **Developer info + data safety:** reuse Play's data-safety answers; permissions = Usage Access, Overlay, Activity Recognition, Health Connect, Notifications.
- [ ] **Promos (bonus):** upload a 30–60s promo video + banner if the console asks — helps featuring.

## A.3 Ready-to-paste copy

**Title:**
```
Fravo — Walk to Earn Screen Time
```

**Short description (≤80):**
```
Walk 1,000 steps to earn screen time. Block Instagram,
TikTok & more when time runs out.
```

**Long description (Indus style — concise, positive):**
```
Fravo turns your daily steps into screen time you can feel.

HOW IT WORKS
1. Pick the apps you scroll too much (Instagram, TikTok, YouTube & more)
2. Walk 1,000 steps to earn screen time
3. When your time runs out, Fravo blocks the app until you earn more

WHY FRAVO
• Real app blocker — actually locks the app, not just a reminder
• Reward, not punishment — the more you walk, the more you get
• Works with your phone's step counter + Health Connect
• 15+ popular apps ready to pick, or add any app
• All data stays on your device. No account. No ads.

Built for people who want a healthier relationship with their phone.
```

**Hindi (हिंदी) sample — use as base for localization:**
```
Title: Fravo — चलें और स्क्रीन टाइम कमाएं
Short: 1,000 कदम चलें और स्क्रीन टाइम कमाएं। समय खत्म होने पर इंस्टाग्राम, टिकटॉक ब्लॉक हो जाते हैं।
Long (first para): Fravo आपके रोज़ के कदमों को स्क्रीन टाइम में बदलता है। 1,000 कदम चलें और अपने पसंदीदा ऐप्स के लिए मिनट कमाएं। समय खत्म होने पर ऐप ब्लॉक हो जाता है — और आप और चलकर समय कमा सकते हैं। सज़ा नहीं, इनाम।
```

---

# B. SOFTONIC (Worldwide software portal)

**Why bother:** Free worldwide distribution (Windows/Mac/Android/iOS), millions of monthly visitors, wide international reach — cheap visibility outside India and a second public home for the APK. Their AI-assisted publishing center makes multilingual listings easy.

**Portal:** https://publishing-center.softonic.com/

## B.1 Submission checklist
- [ ] Create account on Publishing Center (free; no fee for uploads/managing)
- [ ] **Create a new listing** (or claim if one exists — unlikely for Fravo)
- [ ] **Upload signed release APK** (`flutter build apk --release` — APK, not AAB, for direct hosting)
- [ ] **Descriptions in multiple languages** — English mandatory; auto-translate tool available. Add Hindi/Spanish/French later if rankings show demand.
- [ ] **Screenshots:** 2–4 phone screenshots (same 1080×1920 set as Play)
- [ ] **Add version + update note** for each release (e.g. "v1.0.0 — initial release")
- [ ] Expect a **review pass** (quality + content policies) before it goes live; they can reject based on catalog relevance — keep metadata clean and accurate
- [ ] Updates: push new APKs + bump version notes through the same center

## B.2 Ready-to-paste copy (Softonic format — punchy intro, feature list, bottom line)

**Title:**
```
Fravo - Walk to Earn Screen Time
```

**Intro (first paragraph):**
```
Fravo turns your daily steps into screen time: walk 1,000 steps and earn
minutes on the apps you love. When your time runs out, Fravo blocks the
app until you earn more - a reward-based digital wellbeing app, not a guilt trip.
```

**Features (bullets):**
```
- Walk to earn screen time: 1,000 steps = configurable minutes (5-60)
- Real app blocker with a full-screen block overlay (not just reminders)
- Block Instagram, TikTok, YouTube & any app by package name
- 15+ popular app presets, ready in one tap
- Dual-mode step tracking: hardware pedometer + Health Connect
- Real-time usage sync and midnight reset for a fresh start
- Emergency pass: spend 1,000 steps for 3 extra minutes in a pinch
- Privacy-first: no account, no ads, data stays on your device
```

**Bottom line:**
```
A healthier phone habit, earned one step at a time. Fravo is the screen
time app that rewards movement instead of punishing scrolling.
```

---

# C. Shared asset pack (make once, use everywhere)

| Asset | Spec | Used by |
|---|---|---|
| App icon | 1024×1024 PNG, no transparency in corners | Play / Indus / Softonic |
| Screenshots | 3–8 × 1080×1920 (9:16), real screens, no device frames | Play / Indus / Softonic |
| Promo video | 30–60s (store version) + ≤2 min (Shipaton version) | Indus promos / Devpost |
| Privacy policy | Already live (netlify + PRIVACY_POLICY.md) | All stores |
| Description master | English base (this doc + ASO doc) | All stores |
| Developer identity | PAN/ID + address proof scan | Indus |
| Signed release builds | AAB (Play/Indus) + APK (Indus/Softonic) | All stores |

**Enforcement tip:** keep Play + Indus + Softonic listings from drifting apart — update all three in the same release cycle. Google's cross-checking and user confusion both punish inconsistency.