# Fravo

Walk to earn screen time. Fravo converts your daily steps into allowed app usage — walk 1,000 steps and unlock minutes of screen time for your chosen apps.

## How It Works

1. Select apps you want to limit (Instagram, TikTok, YouTube, etc.)
2. Walk to earn screen time — 1,000 steps = configurable minutes (default 30 min)
3. When your time runs out, the selected apps are blocked until you walk more

## Features

- **Step-to-screen-time rewards** — configurable rate (5–60 min per 1,000 steps)
- **Multi-app blocking** — block multiple apps simultaneously
- **Dual-mode step tracking** — hardware pedometer (instant) + Health Connect (accurate, every 5 min)
- **Real-time usage sync** — native layer syncs every 30 seconds
- **Delta-based used-time tracking** — survives app relaunches and daily resets
- **Block screen overlay** — shows when a blocked app is opened
- **Custom package names** — add any app by its package identifier

## Permissions Required

| Permission | Purpose |
|---|---|
| Usage Access | Read screen time for each app |
| Display Over Other Apps | Show block screen overlay |
| Notifications | Show "Fravo Active" status notification |
| Activity Recognition | Track steps from hardware sensor |
| Health Connect (Read) | Fetch accurate step count |

## Tech Stack

- **Framework:** Flutter (Dart)
- **Min SDK:** Android 26 (Android 8.0)
- **Key packages:** `zo_app_blocker`, `health`, `pedometer`, `permission_handler`, `hive`

## Building

```bash
# Install dependencies
flutter pub get

# Run analysis
flutter analyze

# Run tests
flutter test

# Run on device
flutter run
```

## Daily Reset

Step counts and screen time reset automatically at midnight local time.

## License

Private — not published to pub.dev.
