# macsync

A personal macOS background **lifelogging** app. Runs invisibly from the menu bar,
collects contextual activity data, buffers it locally, and syncs a compiled daily
archive to iCloud Drive.

**Repo:** https://github.com/tapchipswipe/macsync

> ⚠️ **Privacy notice (read first)**
> macsync records data *about your own computer usage* on *your own machine*.
> All data stays on your Mac and in *your own* iCloud Drive — nothing is sent anywhere else.
> The input tracker logs **counts only** (keystroke/click totals, cursor distance).
> It **never** records which keys you pressed or any text. Do not install this on
> machines you do not own or without the knowledge of everyone using the machine.

## What it collects

| Module | Source | Data |
|---|---|---|
| App & window focus | `NSWorkspace` + `CGWindowList` | frontmost app, window titles, focus durations |
| Input metrics | `CGEvent.tapCreate` | keystroke/click **counts**, scroll events, cursor distance (metadata only) |
| Browser activity | AppleScript | active tab URL + title from Safari / Chrome (only while that browser is frontmost) |
| Hardware | IOKit / Mach / getifaddrs | battery %, CPU load, RAM pressure, network bytes/sec |
| Idle sessions | `CGEventSource.secondsSinceLastEventType` | when you step away (≥ 5 min) |
| Location | CoreLocation | periodic pings (significant-change + hourly) |

## Data & sync

- Local buffer: `~/Library/Application Support/macsync/buffer/events-YYYY-MM-DD.jsonl`
- Daily auto-sync at **23:59** (with an hourly `NSBackgroundActivityScheduler` watchdog
  that catches up if the Mac was asleep). "Sync Now" from the menu exports today so far.
- Output: `macsync_YYYY-MM-DD.json` — a structured archive with per-kind event counts
  and a daily summary (keystroke totals, per-app usage, idle time, battery range).
- Destination resolution: iCloud ubiquity container → `~/Library/Mobile Documents/com~apple~CloudDocs/macsync/` → local `Exports/` fallback.

## Build

```bash
./build.sh
```

Uses `xcodebuild` if full Xcode is installed (optionally with `xcodegen` to generate
the project); otherwise falls back to compiling directly with `swiftc` from Command
Line Tools. Output lands in `build/`:

- `build/macsync.app` — signed with the stable local `macsync-dev` identity (falls back to ad-hoc)
- `build/macsync.dmg` — mountable installer image (drag to Applications)

> **Signing & permissions note.** For Accessibility/Screen-Recording grants to be
> honored by macOS, the app must return the *same* signature on every launch. Ad-hoc
> (`-`) signing produces a fresh cdhash each build, which silently invalidates granted
> permissions. `build.sh` therefore prefers a locally-created **self-signed
> `macsync-dev` code-signing identity** and only falls back to ad-hoc if it is absent.
> Generate it once with:
>
> ```bash
> openssl req -x509 -newkey rsa:2048 -nodes \
>   -keyout ~/.macsync-dev.key -out ~/.macsync-dev.crt -days 3650 \
>   -subj "/CN=macsync-dev"
> security import ~/.macsync-dev.key -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign
> security import ~/.macsync-dev.crt  -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign
> security add-trusted-cert -d -r trustRoot -p codeSign \
>   -k ~/Library/Keychains/login.keychain-db ~/.macsync-dev.crt
> ```

## First run & permissions

On first launch the app walks you through granting (one-time only, and only what is
missing; afterwards it stays silent):

1. **Accessibility** — required for input counts (`System Settings → Privacy & Security → Accessibility`)
2. **Screen Recording** — required for window titles (`→ Privacy & Security → Screen Recording`)
3. **Automation** — required for Safari/Chrome tab queries (prompted on first use)
4. **Location** — requested on launch

After granting Accessibility/Screen Recording you must **fully quit and relaunch** the
app (`killall macsync`, then reopen) for the change to take effect — macOS reads these
grants at process start. If a permission is denied, the affected module logs errors
instead of data; everything else keeps working. Use "Request / Review Permissions…"
in the menu to re-trigger any missing ones.

## Launch at Login

Toggle from the menu bar dropdown, or manage it manually in
**System Settings → General → Login Items**. The menu toggle re-reads the real system
status every time the menu opens, so it stays in sync with manual changes. If macOS
shows "approval needed," use the menu shortcut to jump straight to Login Items settings.

## Architecture

```
Sources/macsync/
├── MacsyncApp.swift         @main, MenuBarExtra
├── MenuContentView.swift    menu dropdown UI
├── AppState.swift            central state, launch-at-login (SMAppService), lifecycle
├── Models.swift              Codable event envelope + payloads + day archive
├── Collectors/               AppWindow / InputMetrics / Browser / Hardware / Idle / Location
├── Storage/DataStore.swift   append-only JSONL buffer + stats
├── Sync/                     SyncScheduler (23:59 + watchdog) / iCloudSync (destinations)
└── Permissions/PermissionsManager.swift
```

Requirements: macOS 14+. Non-sandboxed by design (event taps + AppleScript).
