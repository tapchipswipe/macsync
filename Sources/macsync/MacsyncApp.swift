import SwiftUI

@main
struct MacsyncApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(appState: appState)
        } label: {
            Image(systemName: appState.isTracking ? "waveform.path.ecg" : "waveform.path.ecg.rectangle")
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.window)

        Window("macsync Dashboard", id: SceneID.dashboard) {
            DashboardView()
                .environmentObject(appState)
        }
        .defaultSize(width: 760, height: 640)
        .windowResizability(.contentSize)
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
