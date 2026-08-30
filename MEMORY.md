# macsync — Project Memory & State

Persistent context for future development sessions. **Read this first.**

## What this is

A macOS menu-bar lifelogging agent ("macsync", formerly OmniTracker) that collects
supplementary user-activity metadata and syncs a daily JSON archive to iCloud Drive.
Repo: `github.com/tapchipswipe/macsync`. Local: `/Users/lucasdespot/macsync`.

## Key committed facts

- **Version**: `0.5.2` in `Info.plist` (bump per release).
- **History**: v0.1.0 initial build → v0.2.0 visual overhaul → v0.3.0 context pack part 1
  → v0.3.1 update checker → v0.3.2 Secure Input → v0.3.3 blank-tab fix + focus ring
  → v0.4.0 context pack part 2 (8 new collectors) → v0.5.0 receipts & spending
  → v0.5.1 receipt filter refinements ($0 / decline rejection) → v0.5.2 investment,
  banking, flight alert, and cloud budget exclusion (hard gate on brokerage/trade
  platforms like Public/Robinhood, airline flight status/check-in/SkyMiles alerts,
  cloud budget thresholds, and banking transfers; 110 tests).
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

## V0.5.0 RECEIPTS & SPENDING — DONE (shipped as v0.5.0)

**Capture is OPT-IN and OFF by default** (`macsync.receiptCaptureEnabled`).
When off, no email bodies are ever read.

- `ReceiptMailCollector` (Collectors/): two-pass AppleScript against Mail.app
  (works with Gmail accounts connected to Mail — verified against
  despotlucas@gmail.com). Pass A lists recent ids/subjects/senders (fast
  `whose date received` filter + 400 cap — do NOT iterate all messages, times
  out on big inboxes). Pass B fetches bodies only for ids passing
  `ReceiptParser.looksLikeReceipt`, and marks them processed.
- Dedup: `state/processed-receipt-messages.json` (last 2000 ids). Deleting that
  file re-stores everything — the Aug-30 test duplicates came from manually
  wiping it mid-test, not from a code bug.
- `ReceiptParser` (Spend/): labeled totals ("Total: $x") beat bare "$x";
  card masks ("ending in 1234", "•••• 1234", "XXXX 1234") → last4;
  merchant = subject "receipt from X" > known sender domain (~45 rules).
  Confidence <0.75 → needsReview (flagged in Wallet tab). NOTE: marketing
  emails with "$60 off" style text produce false positives — they are flagged
  needsReview, and the user can re-categorize/dismiss in the UI.
- Receipts are stored with `ts` = the message’s received date → they land in
  that day’s buffer file and ride that day’s archive to iCloud.
- `SpendStats` rollups (by month/category/card/merchant + deductible total);
  `eventsForMonth` combines buffer + archived days.
- UI: Wallet menu tab (month total, deductible, by-category, by-card chips,
  recent receipts, Add Receipt… sheet for cash/paper), Dashboard spendSection
  (Today/Week/Month), Settings WALLET section (capture toggle, CSV/JSON export,
  open spend folder).
- Export: `~/Documents/macsync-spend/macsync-receipts-YYYY-MM-DD.csv|json`.
- Smoke-tested live: 11 stored / 3 skipped-no-amount / rescan "0 fresh".

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