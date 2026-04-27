//
//  SettingsWindowManager.swift
//  DynamicIsland
//
//  Presents app settings in a standard titled window (not the floating island).
//

import AppKit
import SwiftUI

@MainActor
final class SettingsWindowManager: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let activationPolicyOnClose: () -> Void

    /// `activationPolicyOnClose` should restore the menu-bar (accessory) policy when no other regular window
    /// (e.g. onboarding) is visible.
    init(activationPolicyOnClose: @escaping () -> Void) {
        self.activationPolicyOnClose = activationPolicyOnClose
        super.init()
    }

    /// True while the settings window exists and is visible (used to avoid demoting activation policy while it is open).
    func isWindowOpen() -> Bool {
        window?.isVisible == true
    }

    func show(keyboardMonitor: GlobalKeystrokeMonitor) {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = IslandSettingsView(
            keyboardMonitor: keyboardMonitor,
            permissions: PermissionManager.shared
        )
        let controller = NSHostingController(rootView: view)
        controller.view.wantsLayer = true
        controller.view.frame = NSRect(x: 0, y: 0, width: 820, height: 640)

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.title = "Dynamic Island"
        win.isOpaque = false
        win.backgroundColor = .clear
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        if #available(macOS 11.0, *) {
            win.titlebarSeparatorStyle = .none
        }
        if #available(macOS 13.0, *) {
            win.toolbarStyle = .unified
        }
        win.contentViewController = controller
        win.setContentSize(NSSize(width: 820, height: 640))
        win.minSize = NSSize(width: 720, height: 480)
        win.center()
        win.delegate = self
        if let screen = NSScreen.main {
            let vf = screen.visibleFrame
            if win.frame.maxY > vf.maxY {
                var r = win.frame
                r.origin.y = vf.maxY - r.height
                win.setFrame(r, display: true)
            }
        }

        self.window = win
        NSApp.setActivationPolicy(.regular)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === window else { return }
        window = nil
        activationPolicyOnClose()
    }
}
