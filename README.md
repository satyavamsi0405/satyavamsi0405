# Quick Math Sprint (Android)

A native Android app (Kotlin + Jetpack Compose) for timed mental-math drills:
single digit → double digit → triple digit → mixed, with a countdown round
timer and an end-of-round stats screen. Best score per level is saved on
device (SharedPreferences), so it persists between sessions.

## How to build it

### Option A — Android Studio (needs a computer)

1. Install [Android Studio](https://developer.android.com/studio) (free).
2. `File → Open`, select this `QuickMathSprint` folder.
3. Let Gradle sync (first sync downloads the Android Gradle Plugin, Kotlin,
   and Compose libraries — needs internet once).
4. Press ▶ Run with an emulator or a phone connected via USB debugging.

No manual setup beyond that — minSdk 24 (Android 7.0+), targetSdk 34.

### Option B — build the APK in the cloud (phone only, no computer)

This project includes `.github/workflows/build.yml`, which builds a debug
APK on GitHub's servers whenever you push. All you need is a phone and the
GitHub app (or mobile browser).

1. On github.com (or the GitHub mobile app), create a new empty repository,
   e.g. `quick-math-sprint`.
2. Get this project's files into that repo. Easiest from a phone: in the
   GitHub app / web UI use "Add file → Upload files" and upload the
   contents of this folder (keep the folder structure — `app/`, `.github/`,
   etc. all need to land at the repo root).
3. Once pushed, go to the repo's **Actions** tab. The "Build debug APK"
   workflow runs automatically on push (or tap "Run workflow" to trigger it
   by hand).
4. When it finishes (green check, a couple of minutes), open that run and
   download the **QuickMathSprint-debug-apk** artifact — it's a zip
   containing `app-debug.apk`.
5. On your Android phone: unzip it (any file manager/zip app handles this),
   tap `app-debug.apk`, and allow "install unknown apps" for that app if
   prompted. It installs like any other app.

No Android SDK, no Gradle install, no laptop — GitHub's runner has
everything preinstalled.

## Project layout

- `app/src/main/java/com/quickmath/sprint/MainActivity.kt` — the entire app:
  screens (Home → Countdown → Game → Results), problem generation, timer
  logic, and score persistence.
- `app/src/main/AndroidManifest.xml`, `res/values/` — manifest and minimal
  resources (Compose draws everything else in code).

## Levels

| Level | Range | Operations |
|---|---|---|
| Single digits | 1–9 | + − × |
| Double digits | 10–99 | + − ×  (× keeps one factor 2–9) |
| Triple digits | 100–999 | + − |
| Mixed bag | random mix of the above | + − × |

Subtraction always keeps the answer non-negative (larger operand first).

## Customizing

- Round lengths: edit `DURATIONS` in `MainActivity.kt`.
- Add a level (e.g. division): add an entry to `LEVELS` and extend
  `generateProblem()`.
- Colors/theme: top of `MainActivity.kt` (`Bg`, `Amber`, `Green`, etc.).
