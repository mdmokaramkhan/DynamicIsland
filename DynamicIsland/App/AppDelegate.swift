//
//  AppDelegate.swift
//  DynamicIsland
//
//  Owns the floating island panel's lifecycle: installs it at launch,
//  anchors it to the main display's notch area, and keeps it positioned
//  correctly when the screen configuration changes.
//

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: IslandPanel?
    private var statusItem: NSStatusItem?
    private var monitorStatusMenuItem: NSMenuItem?
    private var captureToggleMenuItem: NSMenuItem?
    private var soundToggleMenuItem: NSMenuItem?
    private var isCaptureEnabled = true
    private let keyboardMonitor = GlobalKeystrokeMonitor()
    private let keystrokeStore = KeystrokePanelStore()
    private let soundPlayer = KeystrokeSoundPlayer()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // No Dock icon, no app-switcher entry — this is a pure overlay.
        NSApp.setActivationPolicy(.accessory)

        installStatusItem()
        installPanel()
        keyboardMonitor.onEvent = { [weak self] eventType, event in
            guard let self else { return }
            self.keystrokeStore.process(eventType: eventType, event: event)
            self.soundPlayer.play(eventType: eventType, event: event)
        }
        keyboardMonitor.start()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        keyboardMonitor.stop()
        keyboardMonitor.onEvent = nil
    }

    // MARK: - Panel setup

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            if let image = makeStatusBarIslandIcon() {
                button.image = image
            } else {
                button.title = "DI"
            }
            button.toolTip = "DynamicIsland"
        }

        let menu = NSMenu()
        let monitorStatusItem = NSMenuItem(title: keyboardMonitor.statusLine,
                                           action: nil,
                                           keyEquivalent: "")
        monitorStatusItem.isEnabled = false
        monitorStatusItem.image = makeBadgeIcon(symbol: "info.circle.fill", backgroundColor: .systemBlue)
        monitorStatusMenuItem = monitorStatusItem
        menu.addItem(monitorStatusItem)
        menu.addItem(.separator())

        menu.addItem(makeGroupHeader(title: "Monitoring"))

        let captureToggleItem = NSMenuItem(
            title: "",
            action: #selector(toggleCapture),
            keyEquivalent: ""
        )
        captureToggleMenuItem = captureToggleItem
        updateCaptureMenuItem()
        menu.addItem(captureToggleItem)

        let accessibilityItem = NSMenuItem(
            title: "Open Accessibility Settings",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        accessibilityItem.image = makeBadgeIcon(symbol: "figure.wave", backgroundColor: .systemTeal)
        menu.addItem(accessibilityItem)
        menu.addItem(.separator())

        menu.addItem(makeGroupHeader(title: "Sound"))

        let soundToggleItem = NSMenuItem(
            title: "",
            action: #selector(toggleSound),
            keyEquivalent: ""
        )
        soundToggleMenuItem = soundToggleItem
        updateSoundMenuItem()
        menu.addItem(soundToggleItem)

        menu.addItem(.separator())
        menu.addItem(makeGroupHeader(title: "App"))

        let quitItem = NSMenuItem(
            title: "Quit DynamicIsland",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.image = makeBadgeIcon(symbol: "power", backgroundColor: .systemRed)
        menu.addItem(quitItem)

        for menuItem in menu.items where menuItem.action != nil {
            menuItem.target = self
        }
        item.menu = menu

        statusItem = item

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateStatusMenuTitle),
            name: .globalKeystrokeMonitorStatusChanged,
            object: keyboardMonitor
        )
    }

    private func installPanel() {
        let host = NSHostingView(rootView: DynamicIslandView(
            keyboardMonitor: keyboardMonitor,
            keystrokeStore: keystrokeStore
        ))
        host.frame = NSRect(origin: .zero, size: IslandMetrics.panelSize)
        host.autoresizingMask = [.width, .height]

        let panel = IslandPanel.make(contentView: host)
        self.panel = panel

        if let screen = targetScreen() {
            panel.reposition(on: screen)
        }

        panel.orderFrontRegardless()
    }

    private func targetScreen() -> NSScreen? {
        // Prefer the screen currently containing the mouse cursor's menu bar,
        // falling back to `main` (the active/focused screen) and finally to
        // any available screen.
        NSScreen.main ?? NSScreen.screens.first
    }

    // MARK: - Screen changes

    @objc private func screenParametersChanged(_ note: Notification) {
        guard let panel, let screen = targetScreen() else { return }
        panel.reposition(on: screen)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func openAccessibilitySettings() {
        keyboardMonitor.openAccessibilitySettings()
    }

    @objc private func updateStatusMenuTitle() {
        guard let menuItem = monitorStatusMenuItem else { return }
        menuItem.title = isCaptureEnabled ? keyboardMonitor.statusLine : "Keyboard: capture paused"
    }

    @objc private func toggleCapture() {
        isCaptureEnabled.toggle()

        if isCaptureEnabled {
            keyboardMonitor.start()
        } else {
            keyboardMonitor.stop()
            keystrokeStore.clear()
        }

        updateCaptureMenuItem()
        updateStatusMenuTitle()
    }

    private func updateCaptureMenuItem() {
        guard let captureToggleMenuItem else { return }
        if isCaptureEnabled {
            captureToggleMenuItem.title = "Disable Keystroke Capture"
            captureToggleMenuItem.image = makeBadgeIcon(symbol: "hand.tap.fill", backgroundColor: .systemGreen)
        } else {
            captureToggleMenuItem.title = "Enable Keystroke Capture"
            captureToggleMenuItem.image = makeBadgeIcon(symbol: "hand.raised.slash.fill", backgroundColor: .systemOrange)
        }
    }

    @objc private func toggleSound() {
        soundPlayer.isEnabled.toggle()
        updateSoundMenuItem()
    }

    private func updateSoundMenuItem() {
        guard let soundToggleMenuItem else { return }
        if soundPlayer.isEnabled {
            soundToggleMenuItem.title = "Disable Key Sounds"
            soundToggleMenuItem.image = makeBadgeIcon(symbol: "speaker.wave.2.fill", backgroundColor: .systemGreen)
        } else {
            soundToggleMenuItem.title = "Enable Key Sounds"
            soundToggleMenuItem.image = makeBadgeIcon(symbol: "speaker.slash.fill", backgroundColor: .systemOrange)
        }
    }

    private func makeBadgeIcon(symbol: String, backgroundColor: NSColor) -> NSImage? {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let rect = NSRect(origin: .zero, size: size)
        let badgePath = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
        NSColor(calibratedWhite: 0.10, alpha: 1).setFill()
        badgePath.fill()
        NSColor(calibratedWhite: 1.0, alpha: 0.10).setStroke()
        badgePath.lineWidth = 1
        badgePath.stroke()

        guard let symbolImage = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) else {
            return image
        }

        let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [backgroundColor]))
        let tinted = symbolImage.withSymbolConfiguration(config)
        let iconSize = NSSize(width: 10, height: 10)
        let iconRect = NSRect(
            x: (size.width - iconSize.width) / 2,
            y: (size.height - iconSize.height) / 2,
            width: iconSize.width,
            height: iconSize.height
        )
        tinted?.draw(in: iconRect)

        return image
    }

    private func makeGroupHeader(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func makeStatusBarIslandIcon() -> NSImage? {
        let size = NSSize(width: 18, height: 14)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let pillRect = NSRect(x: 1, y: 3, width: 16, height: 8)
        let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: 4, yRadius: 4)
        NSColor.labelColor.setFill()
        pillPath.fill()

        let glowRect = NSRect(x: 4, y: 2, width: 10, height: 2)
        let glowPath = NSBezierPath(roundedRect: glowRect, xRadius: 1, yRadius: 1)
        NSColor.systemCyan.withAlphaComponent(0.7).setFill()
        glowPath.fill()

        image.isTemplate = false
        return image
    }
}
