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
            if let image = NSImage(systemSymbolName: "viewfinder.circle.fill", accessibilityDescription: "DynamicIsland") {
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
        menu.addItem(monitorStatusItem)
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(
                title: "Open Input Monitoring Settings",
                action: #selector(openInputMonitoringSettings),
                keyEquivalent: ""
            )
        )
        menu.addItem(
            NSMenuItem(
                title: "Open Accessibility Settings",
                action: #selector(openAccessibilitySettings),
                keyEquivalent: ""
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit DynamicIsland",
                action: #selector(quitApp),
                keyEquivalent: "q"
            )
        )
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

    @objc private func openInputMonitoringSettings() {
        keyboardMonitor.openInputMonitoringSettings()
    }

    @objc private func openAccessibilitySettings() {
        keyboardMonitor.openAccessibilitySettings()
    }

    @objc private func updateStatusMenuTitle() {
        guard let menuItem = statusItem?.menu?.items.first else { return }
        menuItem.title = keyboardMonitor.statusLine
    }
}
