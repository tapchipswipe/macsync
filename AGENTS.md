# ⚡ LUMEN SYSTEM MEMORY & ARCHITECTURAL SPECIFICATION

## 🏷️ Identity & Naming Conventions
- **App Name**: **Lumen** (Rebranded from `macsync`).
- **Binary**: `Lumen`
- **Bundle**: `/Applications/Lumen.app`
- **Distribution Package**: `build/Lumen.dmg`
- **Bundle Identifier**: `com.lumen.app`
- **Code Signing**: Stable `macsync-dev` self-signed identity to preserve macOS TCC permissions across builds.
- **Build & Test Pipeline**:
  - Run tests: `./test.sh` (100/100 automated checks)
  - Full Build & Deploy: `./build.sh` (compiles with `swiftc`, packages `Lumen.app` & `Lumen.dmg`, signs, and installs to `/Applications/Lumen.app`).

---

## 🏛️ Comprehensive Architecture & Systems Map

### 1. 🖥️ Floating Glass HUD (`HUD/HUDWindowController.swift`, `HUD/HUDContentView.swift`)
- Borderless, draggable, glassmorphic desktop overlay (`.floating` window level).
- Displays live active focus minutes, real-time typing keys, active project/git branch, and a 1-click Focus Shield button.

### 2. ⏳ Attention Time Machine (`TimeMachine/TimeMachineEngine.swift`, `TimeMachine/TimeMachineScrubberView.swift`)
- 24-hour cognitive scrubber discretizing the day into 288 5-minute frames.
- Replays active window titles, keystroke intensity, meeting status, Wi-Fi networks, receipts, and **Git commit nodes**.

### 3. 📈 Financial Runway & IRS Schedule-C Tax Engine (`Forecast/FinancialForecaster.swift`, `Forecast/FinancialRunwayView.swift`, `Tax/ScheduleCTaxEngine.swift`)
- Linear time-series regression forecasting projected month-end burn rate.
- Mapped Schedule-C tax deduction engine for SaaS (Line 18), hardware (Line 22), and business meals (Line 24b) with live 28% tax savings calculator.

### 4. 🧠 On-Device Neural ⌘K Copilot (`Copilot/LumenCopilotEngine.swift`, `Search/SpotlightPaletteView.swift`)
- Spotlight-style palette triggered by ⌘K.
- Natural language intent synthesis across Power, Git Commits, Subscriptions, Music Flow, iCloud Storage, Taxes, and Work Output.

### 5. ☁️ 6-Pillar iCloud Storage Super-Optimizer Suite
- **1-Click Master Turbo Sweep** (`AppState.runMasterTurboSweep()` in `StorageHelperView.swift`): Evicts backups, triages downloads, trims dev bloat, and clears disposable system caches in 1 pass.
- **Autonomous Storage Guardian** (`Storage/AutoEvictionGuardian.swift`): Runs every 15 mins in background, automatically evicting files if disk space < 15GB.
- **Developer Bloat Trimmer** (`Storage/DeveloperProjectTrimmer.swift`): 1-click cleaner for `node_modules`, `.venv`, `.build`, and `target` directories.
- **Folder Pinning Engine** (`Storage/FolderPinningEngine.swift`): Whitelist protection for local offline repos.
- **iCloud Sync Radar** (`Storage/iCloudSyncRadar.swift`): Real-time pending queue & conflict duplicate resolver.
- **Download Triage Engine** (`Storage/DownloadTriageEngine.swift`): Auto-routes stale installers, media, and spreadsheets to iCloud.
- **Visual Ghost File Inspector** (`Storage/GhostFileInspectorView.swift`): Renders local vs dataless cloud storage ratios.

### 6. 🔋 Apple Silicon Power & Battery Runway Engine (`Power/PowerPacingEngine.swift`, `Power/BatteryRunwayCardView.swift`)
- Reads Apple Silicon SoC package power (Watts), discharge pacing, thermal state, and battery cycle count via IOKit.
- Shows real-time battery runway during deep work (*"Drawing ~4.2W · 6h 45m remaining"*).

### 7. 🚢 Git Output Velocity Linker (`Git/GitVelocityLinker.swift`)
- Scans local repositories (`~/Projects`, `~/repos`, `~/welift_sandbox`) for recent commits, active branches, and messages.
- Pins commit events directly onto the 24-Hour Attention Time Machine.

### 8. 💳 30-Day Predictive Subscription Renewal & Price Hike Radar (`Spend/SubscriptionRenewalCalendar.swift`, `Spend/SubscriptionRenewalCalendarView.swift`)
- Forecasts upcoming 30-day recurring subscription milestones from verified receipts.
- Flags imminent charges (<= 3 days) and alerts on price hike increases.

### 9. 🎵 Cognitive Flow & Audio Profiler (`Audio/AudioFlowProfiler.swift`, `Audio/AudioFlowInsightView.swift`)
- Pairs Apple Music / Spotify playback with keystroke velocity and Focus Scores.
- Generates "Soundtrack to Deep Work" cards highlighting high-productivity music.

### 10. 🛡️ Privacy & Permissions Hub (`Permissions/PermissionsHubView.swift`, `Permissions/PermissionsManager.swift`)
- Unified hub covering Accessibility, Screen Recording, Automation, Location Services, and **Full Disk Access (FDA)**.

---

## ⚡ Global User Rules & Commands
- When the user says `run market bot`, run: `cd /Users/lucasdespot/paper_trading_bot && source venv/bin/activate && python paper_trader.py`
