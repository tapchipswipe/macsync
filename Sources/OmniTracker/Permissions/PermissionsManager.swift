import AppKit
import ApplicationServices
import CoreGraphics
import CoreLocation

/// Central place for privacy-permission checks and first-launch onboarding.
///
/// Permission map:
///   Accessibility     -> required for the CGEvent input tap (metadata counts)
///   Screen Recording  -> required for window titles via CGWindowList
///   Apple Events      -> required for Safari/Chrome tab queries (prompted on first use)
///   Location          -> requested via CLLocationManager
final class PermissionsManager {

    // MARK: - Status (read-only, no prompts)

    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    var hasScreenRecording: Bool {
        CGPreflightScreenCaptureAccess()
    }

    var locationStatus: CLAuthorizationStatus {
        CLLocationManager().authorizationStatus
    }

    var allCriticalGranted: Bool {
        isAccessibilityTrusted && hasScreenRecording
    }

    // MARK: - Onboarding

    /// Runs on first launch (and from the menu). Prompts only for what is missing.
    func runOnboardingIfNeeded(locationTracker: LocationTracker) {
        let onboarded = UserDefaults.standard.bool(forKey: "omnitracker.onboarded")
        if !onboarded || !allCriticalGranted {
            requestAccessibility()
            requestScreenRecording()
            UserDefaults.standard.set(true, forKey: "omnitracker.onboarded")
            if !allCriticalGranted {
                showOnboardingAlert()
            }
        }
        locationTracker.start()
    }

    /// Triggers the Accessibility trust prompt and opens Settings if needed.
    func requestAccessibility() {
        guard !isAccessibilityTrusted else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Triggers the Screen Recording prompt (macOS 10.15+).
    func requestScreenRecording() {
        guard !hasScreenRecording else { return }
        _ = CGRequestScreenCaptureAccess()
    }

    /// Sends a no-op Apple Event to Safari to pre-trigger the Automation consent dialog.
    func requestAutomationConsent() {
        let scripts = [
            "tell application \"Safari\" to count of windows",
            "tell application \"Google Chrome\" to count of windows"
        ]
        for source in scripts {
            // Only prompt for browsers that are actually installed.
            let target = source.contains("Safari") ? "com.apple.Safari" : "com.google.Chrome"
            guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: target) != nil else { continue }
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
        }
    }

    private func showOnboardingAlert() {
        let alert = NSAlert()
        alert.messageText = "OmniTracker needs permissions"
        alert.informativeText = """
        To build your lifelog, OmniTracker needs:

        • Accessibility — counts keystrokes/clicks (metadata only, never what you type)
        • Screen Recording — reads window titles
        • Automation — reads Safari/Chrome tab URLs
        • Location — periodic location pings

        Grant these in System Settings, then return here. The app keeps running either way.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Accessibility Settings")
        alert.addButton(withTitle: "Open Screen Recording Settings")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:  openAccessibilitySettings()
        case .alertSecondButtonReturn: openScreenRecordingSettings()
        default: break
        }
    }

    // MARK: - System Settings deep links

    func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    func openScreenRecordingSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }

    func openAutomationSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
    }

    func openLocationSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!)
    }
}
