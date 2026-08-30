# macsync — Project Memory & State

Persistent context for future development sessions. **Read this first.**

## What this is

A macOS menu-bar lifelogging agent ("macsync", formerly OmniTracker) that collects
supplementary user-activity metadata and syncs a daily JSON archive to iCloud Drive.
Repo: `github.com/tapchipswipe/macsync`. Local: `/Users/lucasdespot/macsync`.

## Key committed facts

- **Version**: `0.4.0` in `Info.plist` (bump per release).
- **History**: v0.1.0 initial build → v0.2.0 visual overhaul (Vorssaint-style tabbed
  menu, Dashboard window w/ Swift Charts) → v0.3.0 context pack part 1 (range tabs,
  context tagging, zombie detection, AES-GCM encryption, night pause, health dot,
  onboarding window, OSLog, unit tests, CI) → v0.3.1 update checker → v0.3.2 Secure
  Input detection → v0.3.3 blank-tab fix + focus ring + per-app history + insights
  tab + menu-bar time readout → v0.4.0 context pack part 2 (8 new collectors:
  sessions, camera/mic, media, network, clipboard, focus, app lifecycle, mail;
  meeting inference; live NOW strip; Dashboard context cards; TCC Focus crash
  fix; 34 tests).
- **Released via GitHub Releases**: `v0.1.0` … `v0.3.3`, each with `build/macsync.dmg`.
- **Design language**: dark Vorssaint-like. `AppTheme` lives in
  `Sources/macsync/Dashboard/DashboardView.swift` (menu + dashboard share it).
  Tab strip + pill footer pattern in `MenuContentView.swift`.
- **Architecture**: SwiftUI `MenuBarExtra` (`.window` style), `@main MacsyncApp`,
  `@MainActor final class AppState` (singleton `shared`) drives tracking/sync/state.
  13+ collectors in `Sources/macsync/Collectors/`. JSONL buffer via `DataStore`.
  Daily sync via `iCloudSync` + `SyncScheduler`. Unit tests via `./test.sh` (22).

## Cold start build command

- **Build**: `cd /Users/lucasdespot/macsync && ./build.sh` — compiles via `swiftc`
  (no full Xcode), bundles `.app`, ad-hoc/`macsync-dev` signs, makes `.dmg`.
  Artifacts in `build/`. **Picks up new files automatically** (globs `Sources/**`).
- **Test**: `./test.sh` — compiles `Tests/` + runs checks. Currently 22/22 passing.
- **Version bump**: `sed -i '' 's|<string>0.3.3</string>|<string>0.4.0</string>|' Resources/Info.plist`
  then rebuild.

## SIGNING / PERMISSIONS (critical)

- Uses a stable self-signed **`macsync-dev`** code-signing identity in the keychain
  (created via OpenSSL + `security add-trusted-cert`). **Ad-hoc signing changes the
  cdhash each rebuild → silently invalidates TCC grants.** The stable identity makes
  Accessibility/Screen Recording/Focus grants persist across rebuilds.
- Permissions requested: Accessibility, Screen Recording, Location, Apple Events
  (browsers + Mail), Focus (Intents). Onboarding window (`OnboardingWindow.swift`)
  requests them; **TCC grants require a full quit + relaunch** (macOS reads at process
  start). If a permission silently fails: `killall macsync`, relaunch.
- TCC resets (for dev): `tccutil reset Accessibility com.macsync.app` (screen
  recording key is `com.apple.screenrecording`, can be blunt-reset via `tccutil reset
## V0.4.0 CONTEXT PACK — DONE (released as v0.4.0)

**8 new collectors** (all in `Collectors/`): Session, CameraMic,
Media (private MediaRemote via `dlopen`/`dlsym`), NetworkContext
(CoreWLAN + VPN scan; BSSID SHA-256 hashed), Clipboard (**metadata only**),
FocusMode (`INFocusStatusCenter`), AppLifecycle, Mail (AppleScript; sender
names opt-in via `macsync.mailSenderNames`). All wired into
`AppState.startTracking()/stopTracking()`; 8 new `Payload` cases in
`Models.swift`.

Aggregator (`TodayStats.swift`/`Insights.swift`): meeting inference (camera on,
or mic-on + meeting frontmost app; 75s gap bridge), media seconds by app,
clipboard sums, mail counts/senders, lock/wake counts, app launches,
Wi-Fi/VPN, Focus, now-playing — plus context insights bullets.

UI: LIVE context strip ("NOW") in the menu Today tab; Dashboard context
section = Sessions / Media / Clipboard sparkline / Mail cards + live meeting
indicator (video bubble w/ LIVE badge when a camera/mic meeting is current;
"Xm on calls today" summary otherwise). Context cards also appear on the
Week/Month ranges.

**TCC crash fix (important)**: `FocusModeCollector` touches
`INFocusStatusCenter`; without `NSFocusStatusUsageDescription` in
`Resources/Info.plist` macOS SIGABRTs the app on every launch (seen in
`~/Library/Logs/DiagnosticReports`). Key added in 0.4.0. If Focus-related
crashes ever reappear, check that key first.

## KNOWN BUILD STATUS (v0.4.0)

- `./test.sh`: **34/34 checks passed** (22 baseline + 12 context-pack).
- `./build.sh`: **0 errors / 0 warnings**, `macsync-dev` signed, DMG ~2MB.
- Smoke-tested: launches + stays running; buffer gains inputMetrics,
  cameraMicState, networkContext, focusModeState, locationPing, appFocus,
  syncResult kinds.
- Benign log noise: `com.apple.linkd.autoShortcut` connection errors (no App
  Intents), MediaRemote "no now-playing client", CFBundle factory warning.

## Next steps (post-v0.4.0 — ideas, not committed)

1. Settings tab: Mail sender-names toggle (`macsync.mailSenderNames`).
2. Weekly digest (notification or email) from archived summaries.
3. In-window archive viewer for past days.
4. Swift 6 strict-concurrency audit of collectors (swiftc 6 toolchain).
5. Night-pause + Sleep schedule polish; per-app clipboard/focus history.

## Common pitfalls

- Editor tool flaked on whitespace-sensitive Swift edits; **use python3 atomic patch
  scripts** for multi-line insertions (idempotent, assert-guarded).
- `git mv`/rename: reflect in `project.yml` too.
- Privacy: input/clipboard/browser are METADATA ONLY. Sender names off by default.
- Window titles require Screen Recording; keystrokes hidden during Secure Input
  (password fields); tap re-enables on `!.tapDisabled`.
  ScreenCapture`).