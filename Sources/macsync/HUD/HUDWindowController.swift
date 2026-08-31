import AppKit
import SwiftUI

@MainActor
final class HUDWindowController: NSObject {
    static let shared = HUDWindowController()
    private var panel: NSPanel?

    func show() {
        if let p = panel {
            p.orderFrontRegardless()
            return
        }

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 44),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = false
        p.isMovableByWindowBackground = true

        let hosting = NSHostingView(rootView: HUDContentView())
        p.contentView = hosting

        // Position in top-right area below menu bar
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.maxX - 360
            let y = screen.visibleFrame.maxY - 60
            p.setFrameOrigin(NSPoint(x: x, y: y))
        }

        p.orderFrontRegardless()
        self.panel = p
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    func toggle() {
        if panel != nil { hide() } else { show() }
    }

    var isVisible: Bool {
        panel != nil
    }
}
