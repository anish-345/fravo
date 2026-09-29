# Universal Guidelines: Flutter, Shorebird OTA & Build Optimization

These rules define standard engineering guardrails for Flutter applications utilizing Shorebird Code Push and Android Gradle builds.

---

## 1. Pure-Dart Fix Invariant for Shorebird OTA Patches

* **Strict Constraint:** **Never modify native code (Kotlin, Java, Swift, Objective-C) when diagnosing or fixing issues intended for Over-The-Air (OTA) patches.**
* **Why:** Shorebird code push (`shorebird patch android / ios`) only distributes updates to Dart AOT machine code and Flutter assets. Native code changes are ignored by patches and will never reach existing users without a full app store release (`shorebird release`).
* **Rule:** Always solve UI lifecycle resets, animation replays, gesture responsiveness, data decoding, icon/asset caching, and background runner event transitions **100% within the Dart layer (`lib/`)**.

---

## 2. Gradle & Android Build Acceleration Standards

To keep compilation and patch packaging times under 60–80 seconds (avoiding 3–4 minute build stalls), ensure `android/gradle.properties` contains these performance flags:

```properties
# Allocate 4GB - 6GB heap to Gradle compiler
org.gradle.jvmargs=-Xmx6144m -XX:+UseParallelGC -XX:MaxMetaspaceSize=1024m -XX:ReservedCodeCacheSize=512m -XX:+HeapDumpOnOutOfMemoryError

# Enable multi-core parallel task execution
org.gradle.parallel=true

# Enable global task & transform build cache
org.gradle.caching=true

# Keep hot Gradle daemon resident in RAM
org.gradle.daemon=true

# Watch file system for instant change detection
org.gradle.vfs.watch=true

# Enable Kotlin incremental compilation
kotlin.incremental=true
kotlin.incremental.useClasspathSnapshot=true

# Skip redundant PNG re-crunching on already optimized asset images
android.enablePngCrunchInReleaseBuilds=false

# Non-transitive R classes for faster AAPT2 resource linking across plugin packages
android.nonTransitiveRClass=true
```

### Windows Real-Time Antivirus Exclusions
When building on Windows, exclude these four directories in Windows Defender (run as Administrator in PowerShell) to eliminate file-scanning disk I/O bottlenecks during `bundleRelease`:
```powershell
Add-MpPreference -ExclusionPath "C:\Users\<user>\path\to\project", "C:\Users\<user>\.gradle", "C:\Users\<user>\AppData\Local\Pub\Cache", "C:\Users\<user>\.shorebird"
```

---

## 3. Shorebird Multi-Release Patching Workflows

* **Explicit Target Release:** Always pass the target release version directly:
  ```bash
  shorebird patch android --release-version=<version>
  ```
  *(Avoids speculative probe builds and downloads the exact base release artifacts immediately).*

* **Legacy Baselines with Asset Changes:** When deploying patches to older historical baselines that contain asset diffs relative to the current working directory, supply:
  ```bash
  shorebird patch android --release-version=<version> --allow-asset-diffs
  ```

* **Multi-Phase Event Handling in Dart Isolates / Overlays:**
  When background runners receive multi-phase native event streams (e.g. initial launch event followed by asynchronous title/icon resolution or Android Recent Apps transitions):
  1. Never overwrite existing non-null fields with transient `null` values.
  2. Parse package names immediately in Dart to display clean titles on Frame 0.
  3. Cache decoded icons in isolate memory and local key-value storage (Hive/SharedPreferences) for 0ms retrieval on repeat triggers.
  4. Use standard `onTap` with `behavior: HitTestBehavior.opaque` on overlay action buttons to ensure touch-slop immunity in system overlay windows.
