import SwiftUI

@main
struct OmniTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(appState: appState)
        } label: {
            Image(systemName: appState.isTracking ? "waveform.path.ecg" : "waveform.path.ecg.rectangle")
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppState.shared.applicationDidFinishLaunching()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppState.shared.applicationWillTerminate()
    }
}
