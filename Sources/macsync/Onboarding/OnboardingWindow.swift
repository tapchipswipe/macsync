import AppKit
import CoreLocation
import SwiftUI

/// A friendly 3-step welcome window (#11) replacing the old NSAlert flow.
@MainActor
final class OnboardingWindowController {
    static let shared = OnboardingWindowController()
    private var window: NSWindow?

    func showIfNeeded(permissions: PermissionsManager) {
        guard !permissions.allCriticalGranted else { return }
        show(permissions: permissions)
    }

    func show(permissions: PermissionsManager) {
        if let w = window, w.isVisible { w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let hosting = NSHostingView(rootView: OnboardingView(permissions: permissions)
            .environmentObject(AppState.shared))
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "Welcome to macsync"
        w.contentView = hosting
        w.center()
        w.isReleasedWhenClosed = false
        window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct OnboardingView: View {
    let permissions: PermissionsManager
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var timer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: [AppTheme.accent, AppTheme.accentDeep],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "waveform.path.ecg").font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
                }
                .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome to macsync").font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("Your private lifelog — data never leaves this Mac.").font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                step(1, "Accessibility", "Counts keystrokes/clicks — metadata only, never what you type",
                     granted: appState.accessibilityGranted,
                     action: { permissions.openAccessibilitySettings() })
                step(2, "Screen Recording", "Reads window titles for your log",
                     granted: appState.screenRecordingGranted,
                     action: { permissions.openScreenRecordingSettings() })
                step(3, "Automation & Location", "Safari/Chrome tab URLs and location pings",
                     granted: CLLocationManager().authorizationStatus == .authorized,
                     action: { permissions.openLocationSettings() })
            }

            Text("After granting, quit and reopen macsync so macOS applies the new permissions.")
                .font(.system(size: 11)).foregroundStyle(.secondary)

            HStack {
                Button("Quit and reopen later") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                Button("Get Started") {
                    UserDefaults.standard.set(true, forKey: "macsync.onboarded")
                    if let w = NSApp.windows.first(where: { $0.title == "Welcome to macsync" }) { w.close() }
                }
                .buttonStyle(.borderedProminent).tint(AppTheme.accent)
            }
        }
        .padding(22)
        .onAppear { startPolling() }
        .onDisappear { timer?.invalidate() }
    }

    private func step(_ n: Int, _ title: String, _ detail: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(granted ? AppTheme.batteryGreen.opacity(0.2) : AppTheme.accent.opacity(0.15))
                if granted {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(AppTheme.batteryGreen)
                } else {
                    Text("\(n)").font(.system(size: 12, weight: .bold)).foregroundStyle(AppTheme.accent)
                }
            }
            .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            if granted {
                Text("Granted").font(.system(size: 11, weight: .semibold)).foregroundStyle(AppTheme.batteryGreen)
            } else {
                Button("Grant") { action() }.buttonStyle(.bordered).controlSize(.small)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.card))
    }

    private func startPolling() {
        timer?.invalidate()
        let t = Timer(timeInterval: 1.5, repeats: true) { _ in
            Task { @MainActor in appState.refreshPermissionStatus() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
}
