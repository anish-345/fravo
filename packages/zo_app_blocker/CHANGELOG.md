## 0.0.1

*  initial release.

## 0.0.2

* Fixed Backward compatibility and added request permission natively.

## 0.0.3

* **New Feature:** Added  Flutter Overlays for custom block screens.
* **Enhancement:** Renamed `setBlockScreenConfig` to `setNotificationConfig`.
* **Fix:** Resolved Kotlin Gradle Plugin (KGP) build compatibility issues.
* **Fix:** Fixed a screen flicker issue when launching a blocked application.

## 0.0.4
* Resolved an issue where the `isOverlayShowing` state wasn't updated correctly when dismissing the block screen or requesting an unlock.


## 0.0.5

* Added app scheduling and daily time limit features.
* Fixed an issue where the app icon was missing in the default block screen.
* Removed accessibility service and replaced it with `QUERY_ALL_PACKAGES` and overlay permissions to comply with Google Play policies.


## 0.0.6

* Removed duration logic as for small amounts it created a race condition.
* Introduced fixed foreground session restriction.
* Renamed `onRequestUnlock` to `onRequestTemporarySessionUnlock` in the Dart API to reflect the new behavior.
