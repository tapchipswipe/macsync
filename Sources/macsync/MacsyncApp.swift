import SwiftUI

@main
struct MacsyncApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(appState: appState)
        } label: {
            // Health dot (#10): red when a permission is missing or sync failed.
            Image(systemName: appState.isTracking ? "waveform.path.ecg" : "waveform.path.ecg.rectangle")
                .symbolRenderingMode(.hierarchical)
                .overlay(alignment: .topTrailing) {
                    if appState.healthIsBad {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                            .offset(x: 5, y: -4)
                    }
                }
        }
        .menuBarExtraStyle(.window)

        Window("macsync Dashboard", id: SceneID.dashboard) {
            DashboardView()
                .environmentObject(appState)
        }
        .defaultSize(width: 940, height: 700)
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
