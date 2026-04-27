//
//  SettingsWindowManager.swift
//  DynamicIsland
//

import AppKit
import SwiftUI

@MainActor
final class SettingsWindowManager: NSObject {

    private var window: NSWindow?
    private var windowCloseObserver: NSObjectProtocol?
    private let activationPolicyOnClose: () -> Void

    init(activationPolicyOnClose: @escaping () -> Void) {
        self.activationPolicyOnClose = activationPolicyOnClose
        super.init()
    }

    func isWindowOpen() -> Bool {
        window?.isVisible == true
    }

    func show(keyboardMonitor: GlobalKeystrokeMonitor, dependencies: AppDependencies = .shared) {

        // 🔁 Reuse existing window
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            animateFocus(window)
            return
        }

        let rootView = IslandSettingsView(
            keyboardMonitor: keyboardMonitor,
            permissions: dependencies.permissionProvider as! PermissionManager
        )

        let hosting = NSHostingController(rootView: rootView)
        hosting.view.wantsLayer = true
        hosting.view.layer?.cornerRadius = 16
        hosting.view.layer?.masksToBounds = true

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 660),
            styleMask: [
                .titled,
                .closable,
                .miniaturizable,
                .resizable,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )

        // MARK: - Apple Style Window

        win.title = ""
        win.isOpaque = false
        win.backgroundColor = .clear
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden

        if #available(macOS 13.0, *) {
            win.toolbarStyle = .unifiedCompact
        }

        win.contentViewController = hosting
        win.setContentSize(NSSize(width: 860, height: 660))
        win.minSize = NSSize(width: 720, height: 500)

        win.isMovableByWindowBackground = true
        win.hasShadow = true
        win.level = .normal
        win.isReleasedWhenClosed = false

        // Better positioning
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let x = frame.midX - 430
            let y = frame.midY - 330
            win.setFrame(NSRect(x: x, y: y, width: 860, height: 660), display: true)
        }

        windowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: win,
            queue: .main
        ) { [weak self] note in
            self?.handleWindowWillClose(note)
        }
        self.window = win

        // Activate app
        NSApp.setActivationPolicy(.regular)
        win.alphaValue = 0
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // 🔥 Smooth Apple-style animation
        animateOpen(win)
    }

    // MARK: - Animations

    private func animateOpen(_ window: NSWindow) {
        window.alphaValue = 0
        window.setFrameOrigin(
            NSPoint(
                x: window.frame.origin.x,
                y: window.frame.origin.y - 10
            )
        )

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)

            window.animator().alphaValue = 1
            window.animator().setFrameOrigin(
                NSPoint(
                    x: window.frame.origin.x,
                    y: window.frame.origin.y + 10
                )
            )
        }
    }

    private func animateFocus(_ window: NSWindow) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            window.animator().alphaValue = 1
        }
    }

    // MARK: - Close
    private func handleWindowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === window else { return }
        if let observer = windowCloseObserver {
            NotificationCenter.default.removeObserver(observer)
            windowCloseObserver = nil
        }
        window = nil
        activationPolicyOnClose()
    }
}
