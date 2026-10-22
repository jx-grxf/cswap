import AppKit
import SwiftUI

/// A sheet on the MenuBarExtra window dies with it: clicking a text field
/// makes the sheet key, the menu window resigns, closes, and takes the sheet
/// along. Adding an account therefore gets a window of its own.
@MainActor
final class AddAccountWindowController: NSWindowController, NSWindowDelegate {
    private static var shared: AddAccountWindowController?

    static func show() {
        if shared == nil {
            shared = AddAccountWindowController()
        }
        shared?.showWindow(nil)
    }

    private init() {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.delegate = self
        window.contentViewController = NSHostingController(
            rootView: AddAccountSheet { [weak window] in window?.close() }
                .environmentObject(AppState.shared)
        )
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        let wasVisible = window?.isVisible == true
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        if wasVisible {
            NSApp.activate(ignoringOtherApps: true)
        } else {
            AppActivationPolicy.enter()
        }
    }

    func windowWillClose(_ notification: Notification) {
        AppActivationPolicy.leave()
        Self.shared = nil
    }
}
