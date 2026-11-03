# Fravo — Shipaton 2026 Demo Video (Final Cut)

**File:** `fravo-shipaton-demo.mp4`
**Duration:** 1:38 (98 s)
**Format:** 1920×1080 (16:9), 30 fps, H.264 + AAC 44.1 kHz stereo
**Audio:** Original synthesised ambient bed — no third-party or copyrighted music

> **Compliance:** Shipaton requires the demo to be **under two minutes**; judges are not
> required to watch beyond 2:00. The original 3:00 screen recording exceeded this. The
> 70 seconds of Play Store install progress (source 14.6 s → 84.7 s) were removed, which
> alone brought the runtime under the limit. Everything submitted must be in English —
> all captions are burned in, so no external subtitle track or voiceover is required.

---

## Timecoded edit

| # | Time | Length | On screen | Source |
|---|------|--------|-----------|--------|
| 1 | 0:00–0:05 | 5.0 s | Title card — "Walk to earn screen time." | Rendered card |
| 2 | 0:05–0:13 | 8.0 s | Google Play listing + install | **Real footage** (src 3.0 s) |
| 3 | 0:13–0:18 | 5.0 s | App launch, Pippy splash | **Real footage** (src 85.0 s) |
| 4 | 0:18–0:32 | 14.0 s | Accessibility engine + "Fravo App Blocker Engine" | **Real footage** (src 92.0 s) |
| 5 | 0:32–0:43 | 11.0 s | Usage access + display-over-other-apps grant | **Real footage** (src 124.0 s) |
| 6 | 0:43–0:55 | 12.0 s | Dashboard with steps banked | Rendered screen |
| 7 | 0:55–1:04 | 9.0 s | Time exhausted, apps blocked | Rendered screen |
| 8 | 1:04–1:10 | 6.5 s | Settings → invite code, "Claim 7 Days Pro" | **Real footage** (src 152.5 s) |
| 9 | 1:10–1:21 | 11.0 s | Fravo Pro paywall (RevenueCat offerings) | Rendered screen |
| 10 | 1:21–1:31 | 10.0 s | My Stats — 7-day activity, screen time breakdown | **Real footage** (src 168.0 s) |
| 11 | 1:31–1:38 | 6.5 s | Outro — RevenueCat recap + judge code | Rendered card |

**Real footage vs rendered screens.** Segments 2, 3, 4, 5, 8 and 10 are frames from your
device recording — the app running for real. Segments 6, 7 and 9 are reconstructions
rendered from the app's own Dart source, used because the recording has no step data
(the phone's pedometer never registered) and never opens the paywall. They use the real
`ThemeData` colours, real tier names ("365-Day Walker Pledge", "30-Day Focus Sprint",
"Lifetime Focus Dedication"), real feature copy and the real CTA string
"I Commit to Walk Daily (7 Days Free)".

**If judges test the live app**, the dashboard and paywall will show their own data
rather than these values. That is expected and fine — the structure, labels and flow are
identical.

---

## Optional voiceover (if you add narration)

The video works silent. If you want a VO pass, this is the script, trimmed to the cut:

**0:00–0:13** — "Fravo turns doomscrolling into movement. Your distraction apps stay locked
until you move. It's live on the Google Play Store today."

**0:18–0:43** — "Fravo doesn't use a timer you can swipe away. It blocks apps at the Android
accessibility layer, the same mechanism the system uses, and it sets up in one pass."

**0:43–1:04** — "One thousand steps banks thirty minutes. Walk, earn, and your Time Bank
fills live. When the bank empties, Instagram locks again — until you walk."

**1:04–1:21** — "Monetisation runs on RevenueCat. The premium entitlement drives every Pro
feature, including the doubled reward rate. Judges: enter the code F-R-A-V-O-P-R-O-M-O on
the live build for seven days of Pro instantly."

**1:21–1:38** — "Seven-day activity tracking and full screen-time breakdown. Built with
RevenueCat. Thank you."

---

## How RevenueCat is used (for the submission write-up)

Drawn from `lib/services/revenuecat_service.dart`, `lib/screens/paywall_screen.dart` and
`lib/services/admob_service.dart`:

1. **Entitlement-driven gating** — the `premium` entitlement is the single source of truth
   for Pro, with a fallback chain across `premium` / `Fravo Pro` / `fravo_pro` / `pro`.
2. **Three-tier offering** — annual, monthly and lifetime, read live from
   `Purchases.getOfferings()` with graceful handling when billing is restricted.
3. **Offline-first cache** — the entitlement result is mirrored into Hive, so Pro UI renders
   instantly on cold start, then re-verifies against the server.
4. **Receipt cross-check** — an active Play subscription token or a non-subscription
   transaction grants access immediately, without waiting for server acknowledgement.
5. **Restore** — `Purchases.syncPurchases()` re-verifies past purchases on demand.
6. **Viral referral trials** — the 7-day Pro pass is tracked locally and reflected to
   OneSignal as `referral_trial_active` for the notification engine.
7. **Catvertising** — AdMob `onPaidEvent` fires `Purchases.adTracker.trackAdRevenue()` with
   the mediator, ad format, unit id, value and a mapped `AdRevenuePrecision`, so ad revenue
   lands in the same RevenueCat dashboard as subscriptions.

That maps directly onto the **Next Gen ($20k)**, **HAMM ($50k)** and **Design ($10k)**
tracks, and the paywall segment exists specifically because Shipaton asks for the
"purchase, subscription, web-payment, or advertising experience" in the first two minutes.

---

## Submission checklist

- [ ] Upload to YouTube as **unlisted** (not private) or Vimeo
- [ ] Paste the link into the Devpost submission form
- [ ] Confirm the app icon is 1024×1024 (`assets/icon/app_icon.png`)
- [ ] At least one screenshot at 1179×2556 with no device frame
- [ ] RevenueCat project ID
- [ ] Judge access code — `FRAVO-PROMO` or your personal `FRAVO-XXXXX`
- [ ] Public Play Store URL

---

## Rebuilding

All assets are generated, not hand-drawn, so the cut can be re-rendered after any copy
change:

```
python make_screens.py   # app screens rendered from the Dart source
python make_assets.py    # 16:9 cards + caption overlays
python build_video.py    # device frame, segment cut, composite
python make_music.py     # original ambient bed
```

Edit the `SEGMENTS` list in `build_video.py` to change timings or ordering, and the
`CAPTIONS` list in `make_assets.py` to change caption text.
