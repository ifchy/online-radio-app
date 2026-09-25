# Phase 1: Playback Engine & Walking Skeleton - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md. This log preserves the alternatives that were considered.

**Date:** 2026-09-25
**Phase:** 01-playback-engine-walking-skeleton
**Areas discussed:** Test station lineup, Skeleton screen, Give-up & resume rules, CI/signing & device testing

---

## Test station lineup

| Option | Description | Selected |
|--------|-------------|----------|
| Research proposes, I verify | Researcher finds official streams covering every format | |
| I'll name them now | Owner lists stations/URLs | |
| Mix | Owner names must-haves, research fills gaps | ✓ |

**User's choice:** Mix. Must-haves: Radio 1 and BG Radio. Probable: Витоша, N-JOY, Energy.

| Option | Description | Selected |
|--------|-------------|----------|
| Add БНР stations to fill gaps | Grow set to 6–7 | |
| Swap out a 'probably' station | Keep exactly 5 | |
| Use the formats your stations offer | Alternate endpoints of the same stations | ✓ |

| Option | Description | Selected |
|--------|-------------|----------|
| Debug-only 'dead primary' test station | Dead first URL + real fallback, debug/profile only | ✓ |
| Real station alternates only | Fallback exercised only on real failures | |

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, add БНР Хоризонт | Flagship station, likely HLS | ✓ |
| No, keep my 5 | БНР comes in Phase 2 | |

---

## Skeleton screen

| Question | Options | Selected |
|----------|---------|----------|
| Layout | Simple list + mini-player / Big-button player only | Simple list + mini-player |
| Diagnostics | Debug panel debug/profile only / Always visible / Logs only | Debug panel debug/profile only |
| Language | gen-l10n BG+EN / BG only / EN only | gen-l10n BG+EN |
| Non-playing states | Short state label / Icon/spinner only | Short state label |

---

## Give-up & resume rules

| Question | Options | Selected |
|----------|---------|----------|
| Retry budget | 3 min/10 min (rec.) / 5 min/30 min / 1 min/5 min | Free text: the recommendation as default, plus a future "trip mode" (longer) and "battery saver" (shorter) |
| Long call | Always resume / Resume only if call < ~10 min | Always resume |
| Notification buttons | Play/Pause + Stop / Play/Pause only / Stop only | Play/Pause + Stop |
| Pause linger | Drop FGS, keep notification / Auto-stop after ~10 min | Drop FGS, keep notification |

**Notes:** The engine gets `RetryBudget` presets (standard/trip/batterySaver). The user-facing toggle is deferred as scope creep, because it needs a settings UI.

---

## CI, signing & device testing

| Question | Options | Selected |
|----------|---------|----------|
| Keystore | No, guide me / Yes, I have one / Defer to Phase 4 | No, guide me in the plan |
| Delivery | CI APK artifact + local run / Local only / Play internal track | CI APK artifact + local `flutter run` |
| Devices (multi) | Xiaomi / Samsung / old Android 7–9 / car BT | Xiaomi, Samsung, car BT, plus free text "car with Android Auto" |
| Codegen | Commit generated / Generate in CI | Commit generated files |

**Notes:** With no old device, minSdk 24 is checked on an API 24 emulator. Android Auto is v1.1, so Phase 1 car tests use plain Bluetooth.

---

## Claude's Discretion

- Exact trip/saver numbers, backoff schedule, watchdog/connect timeouts
- Placeholder icon and skeleton styling
- Debug panel layout
- Whether PRs also upload a debug APK

## Deferred Ideas

- User-facing Trip mode / Battery saver toggle → Phase 3 or v1.1 backlog
- Android Auto car testing → v1.1
