---
phase: 01-playback-engine-walking-skeleton
plan: 02
subsystem: ci-release
tags: [github-actions, ci, signing, keystore, aab, apk, apksigner, aapt2, play-app-signing]

# Dependency graph
requires:
  - phase: 01-playback-engine-walking-skeleton (plan 01)
    provides: "Flutter project, pubspec.lock, engine folder layout and the manifest the CI checks"
provides:
  - ".github/workflows/ci.yml: on PRs and pushes to main runs codegen staleness, flutter analyze, dart analyze, flutter test, a tracking-SDK deny-list, the engine import boundary, and release-APK checks (merged manifest, aapt2 SDK levels, debug-station leak). It has no secret access."
  - ".github/workflows/release.yml: on v* tags and workflow_dispatch builds a signed release AAB + APK sharing versionCode = run number. It has a secrets-required guard, a debug-certificate and same-signer check, a debug-station check, and cleanup with if: always()."
  - "android/app/build.gradle.kts: explicit compileSdk 36 / minSdk 24 / targetSdk 36; release signing from gitignored android/key.properties, with a debug fallback."
  - "docs/RELEASE-SIGNING.md: the owner guide to the upload keystore, the four secrets, tagging, sideloading and signer checks."
  - "Owner-held upload key (CN=Ivaylo Kasaivanov, O=iDev Ltd), SHA-256 1a0b9cf361bf156d57336481f624e362b668cb5b5774ac4c3833d0bc8585ea31, and the four GitHub Actions secrets"
affects: [01-10, 01-11, 01-12, 01-13, phase-4-store-release]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SDK-level and signer assertions must accept both the old and new output formats of Android build-tools (aapt2 sdkVersion/minSdkVersion; apksigner 'Signer #1'/'V2 Signer:'), because the GitHub runner's build-tools are newer than the local ones"
    - "Signing secrets exist only in release.yml (tags and dispatch). ci.yml references none and no workflow uses pull_request_target."

key-files:
  created:
    - .github/workflows/ci.yml
    - .github/workflows/release.yml
    - docs/RELEASE-SIGNING.md
  modified:
    - .gitignore
    - android/app/build.gradle.kts

key-decisions:
  - "PR builds are never uploaded as artifacts. Their APK is debug-signed and would clash with CI-signed installs (D-15)."
  - "Pre-release tags follow v0.1.0-rc.N. A tag is never moved; a fix gets a new rc number."
  - "The upload key was created by the owner on their Mac. Claude never saw or handled the keystore or its passwords (D-14)."

requirements-completed: [PLAT-04, PLAT-01]

# Metrics
duration: ~1 day (owner step included)
completed: 2026-09-26
---

# Phase 1 Plan 02: CI, signed release builds and the upload key — Summary

**Every PR now gets analyze, test and release-build safety checks. Version tags produce an AAB and an APK signed with the owner's upload key, and no key material has ever touched the public repo.**

## Accomplishments

- **Task 1** (`d1c7c34`) added:
  - `ci.yml` (analyze-test and release-apk-checks jobs)
  - `release.yml` (signed AAB + APK)
  - explicit SDK levels 36/24/36 in Gradle
  - `key.properties` signing with a debug fallback
  - the `*.b64` ignore rule
  - `docs/RELEASE-SIGNING.md`
- **Task 2 (owner):** the owner created the upload keystore, set `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD` and `ANDROID_KEY_ALIAS`, and tagged `v0.1.0-rc.3` (`b999f50`). The release run built green, and the APK is signed by `CN=Ivaylo Kasaivanov, OU=izkai, O=iDev Ltd, L=Yambol, ST=Yambol, C=BG`.
- **Secret hygiene verified on 2026-09-26:** `git ls-files` and `git log --all --name-only` for `*.jks`, `*.keystore`, `*.b64` and `key.properties` both print nothing.

## Deviations from Plan

### Auto-fixed issues

**1. [Rule 1 - Bug] The minSdk check failed on a correct APK (`86e8c37`)**
- **Found during:** the owner's first CI and release runs.
- **Issue:** aapt2 from build-tools 36 prints `minSdkVersion:'24'`, not `sdkVersion:'24'`. Both `ci.yml` and `release.yml` failed with "Release APK minSdk is not 24" even though the APK is minSdk 24 / targetSdk 36 (confirmed with a local `aapt2 dump badging`).
- **Fix:** accept either form, `(sdkVersion|minSdkVersion):'24'`. The check still rejects minSdk 23.
- **Landed via:** PR #4.

**2. [Rule 1 - Bug] The signer check reported a correctly signed APK as unsigned (`b999f50`)**
- **Found during:** release run for `v0.1.0-rc.2`.
- **Issue:** the runner's newer apksigner prints `V2 Signer: certificate DN:`, not `Signer #1 certificate DN:`, so "The release APK has no signer certificate" fired on an APK signed with the upload key.
- **Fix:** match `^(Signer #1|V[0-9.]+ Signer:) certificate` for both the DN and the SHA-256 digest. Tested against the runner format (passes, fingerprint extracted), a debug-signed APK (debug is still detected) and an unsigned one (still fails).
- **Process note:** this commit was pushed directly to `main` rather than through a PR, because the checkout had been switched to `main` after PR #4 merged. The owner was told. Remaining Phase 1 work continues on `gsd/phase-01-playback-engine-walking-skeleton`.

## Issues Encountered

- Tags `v0.1.0-rc.1` (`2098ee5`) and `v0.1.0-rc.2` point at commits without the fixes, and their release runs fail. They are left in place; `v0.1.0-rc.3` is the first good signed build.
- The GitHub CLI (`gh`) is not installed on the owner's Mac. The secrets were set through the web UI.

## Owner checks still open

- Sideload `app-release.apk` from the `eradioto-v0.1.0-rc.3` artifact onto the phone and open it once (Task 2, step 5).
- Install on an Android 7.0 (API 24) emulator with `flutter run --release` (Task 1 human check 2, PLAT-01).
- Recommended: enable secret scanning, push protection and `main` branch protection (require a PR).

## Next Phase Readiness

- CI-signed APKs are available for the owner's device tests (SC1–SC4) in 01-10 to 01-13.
- Phase 4 (store release) reuses `release.yml` and the upload key with Play App Signing.

---
*Phase: 01-playback-engine-walking-skeleton*
*Completed: 2026-09-26*
