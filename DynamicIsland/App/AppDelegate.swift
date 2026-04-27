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

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var panel: IslandPanel?
    private var statusItem: NSStatusItem?
    private var monitorStatusMenuItem: NSMenuItem?
    private var captureToggleMenuItem: NSMenuItem?
    private var soundToggleMenuItem: NSMenuItem?
    private var mouseClickSoundToggleMenuItem: NSMenuItem?
    private var comboSoundToggleMenuItem: NSMenuItem?
    private var comboPackSubmenuItem: NSMenuItem?
    private var isCaptureEnabled = true
    private let keyboardMonitor = GlobalKeystrokeMonitor()
    private let keystrokeStore = KeystrokePanelStore()
    private let soundPlayer = KeystrokeSoundPlayer()
    private let hitState = IslandHitState()
    private var mouseMonitor: Any?

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
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
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

        // ── App identity header ──────────────────────────────────────────
        let appHeaderItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        appHeaderItem.isEnabled = false
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]
        appHeaderItem.attributedTitle = NSAttributedString(string: "DynamicIsland", attributes: headerAttrs)
        menu.addItem(appHeaderItem)

        // ── Status line ──────────────────────────────────────────────────
        let monitorStatusItem = NSMenuItem(title: keyboardMonitor.statusLine,
                                           action: nil,
                                           keyEquivalent: "")
        monitorStatusItem.isEnabled = false
        monitorStatusItem.image = makeStatusDot(active: true)
        monitorStatusMenuItem = monitorStatusItem
        menu.addItem(monitorStatusItem)
        menu.addItem(.separator())

        // ── Monitoring section ───────────────────────────────────────────
        menu.addItem(makeSectionHeader("Monitoring"))

        let captureToggleItem = NSMenuItem(
            title: "Keystroke Capture",
            action: #selector(toggleCapture),
            keyEquivalent: ""
        )
        captureToggleItem.image = makeMenuIcon(symbol: "keyboard")
        captureToggleMenuItem = captureToggleItem
        updateCaptureMenuItem()
        menu.addItem(captureToggleItem)

        let accessibilityItem = NSMenuItem(
            title: "Accessibility Settings",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        accessibilityItem.image = makeMenuIcon(symbol: "hand.raised")
        menu.addItem(accessibilityItem)
        menu.addItem(.separator())

        // ── Sounds section ───────────────────────────────────────────────
        menu.addItem(makeSectionHeader("Sounds"))

        let soundToggleItem = NSMenuItem(
            title: "Key Sounds",
            action: #selector(toggleSound),
            keyEquivalent: ""
        )
        soundToggleItem.image = makeMenuIcon(symbol: "speaker.wave.2")
        soundToggleMenuItem = soundToggleItem
        updateSoundMenuItem()
        menu.addItem(soundToggleItem)

        let mouseClickSoundToggleItem = NSMenuItem(
            title: "Mouse Click Sounds",
            action: #selector(toggleMouseClickSound),
            keyEquivalent: ""
        )
        mouseClickSoundToggleItem.image = makeMenuIcon(symbol: "cursorarrow.click")
        mouseClickSoundToggleMenuItem = mouseClickSoundToggleItem
        updateMouseClickSoundMenuItem()
        menu.addItem(mouseClickSoundToggleItem)

        let comboSoundToggleItem = NSMenuItem(
            title: "Combo Sounds",
            action: #selector(toggleComboSound),
            keyEquivalent: ""
        )
        comboSoundToggleItem.target = self
        comboSoundToggleMenuItem = comboSoundToggleItem
        updateComboSoundMenuItem()

        let comboPackItem = NSMenuItem(
            title: "Combo Sound Pack",
            action: nil,
            keyEquivalent: ""
        )
        comboPackItem.image = makeMenuIcon(symbol: "command")
        comboPackItem.submenu = makeComboPackSubmenu()
        comboPackSubmenuItem = comboPackItem
        menu.addItem(comboPackItem)
        menu.addItem(.separator())

        // ── App section ──────────────────────────────────────────────────
        let quitItem = NSMenuItem(
            title: "Quit DynamicIsland",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.image = makeMenuIcon(symbol: "power")
        menu.addItem(quitItem)

        for menuItem in menu.items where menuItem.action != nil {
            menuItem.target = self
        }
        menu.delegate = self
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
            keystrokeStore: keystrokeStore,
            hitState: hitState
        ))
        host.frame = NSRect(origin: .zero, size: IslandMetrics.panelSize)
        host.autoresizingMask = [.width, .height]

        let panel = IslandPanel.make(contentView: host)
        self.panel = panel

        if let screen = targetScreen() {
            panel.reposition(on: screen)
        }

        panel.orderFrontRegardless()

        // When SwiftUI signals that the island has collapsed back to idle,
        // re-evaluate whether the panel should ignore mouse events.
        hitState.onExpansionChanged = { [weak self] _ in
            self?.updatePanelMouseIgnore()
        }

        // Start the global mouse monitor that enables the panel when the
        // cursor enters the pill area and disables it when it leaves.
        startMouseTracking()
        updatePanelMouseIgnore()
    }

    // MARK: - Click-through mouse tracking

    /// Returns the collapsed pill's rect in global screen coordinates
    /// (AppKit convention: y=0 at bottom of screen).
    private func pillScreenRect() -> NSRect? {
        guard let panel else { return nil }
        let f = panel.frame
        let pw = IslandMetrics.collapsedSize.width
        let ph = IslandMetrics.collapsedSize.height
        // Add a small inset buffer so hover triggers slightly before
        // the cursor reaches the exact pill edge.
        return NSRect(
            x: f.midX - pw / 2 - 10,
            y: f.maxY - ph - 8,
            width: pw + 20,
            height: ph + 8
        )
    }

    /// Flips `panel.ignoresMouseEvents` based on current cursor position
    /// and island expansion state. Safe to call at any frequency.
    private func updatePanelMouseIgnore() {
        guard let panel else { return }
        let over = pillScreenRect()?.contains(NSEvent.mouseLocation) ?? false
        // Never ignore events while expanded — doing so would prevent
        // onHover(false) from firing and would freeze the island open.
        let shouldIgnore = !over && !hitState.isExpanded
        if panel.ignoresMouseEvents != shouldIgnore {
            panel.ignoresMouseEvents = shouldIgnore
        }
    }

    private func startMouseTracking() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        ) { [weak self] _ in
            self?.updatePanelMouseIgnore()
        }
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
        menuItem.title = isCaptureEnabled ? keyboardMonitor.statusLine : "Capture paused"
        menuItem.image = makeStatusDot(active: isCaptureEnabled)
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
        captureToggleMenuItem?.state = isCaptureEnabled ? .on : .off
    }

    @objc private func toggleSound() {
        soundPlayer.isEnabled.toggle()
        updateSoundMenuItem()
    }

    @objc private func toggleMouseClickSound() {
        soundPlayer.isMouseClickSoundEnabled.toggle()
        updateMouseClickSoundMenuItem()
    }

    @objc private func toggleComboSound() {
        soundPlayer.isComboSoundEnabled.toggle()
        updateComboSoundMenuItem()
    }

    @objc private func selectComboPack(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        soundPlayer.applyComboPack(id: id)
        refreshComboPackMenuCheckmarks()
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard menu === statusItem?.menu else { return }
        soundPlayer.syncMouseClickSoundEnabledWithUserDefaults()
        soundPlayer.syncComboSoundEnabledWithUserDefaults()
        updateMouseClickSoundMenuItem()
        updateComboSoundMenuItem()
        refreshComboPackMenuCheckmarks()
    }

    private func refreshComboPackMenuCheckmarks() {
        guard let submenu = comboPackSubmenuItem?.submenu else { return }
        let currentId = soundPlayer.activeComboSoundPackID
        for item in submenu.items {
            guard let packId = item.representedObject as? String else { continue }
            item.state = packId == currentId ? .on : .off
        }
    }

    private func makeComboPackSubmenu() -> NSMenu {
        let submenu = NSMenu()

        // Toggle item sits at the top of the submenu as a checkmark row
        if let toggle = comboSoundToggleMenuItem {
            toggle.title = "Combo Sounds"
            toggle.image = makeMenuIcon(symbol: "command")
            submenu.addItem(toggle)
        }
        submenu.addItem(.separator())

        let currentId = soundPlayer.activeComboSoundPackID
        for pack in ComboSoundPack.allPacks {
            let item = NSMenuItem(
                title: pack.title,
                action: #selector(selectComboPack(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = pack.id as NSString
            item.image = comboPackIcon(for: pack)
            item.state = pack.id == currentId ? .on : .off
            submenu.addItem(item)
        }

        return submenu
    }

    /// Coloured SF Symbol icons for each combo pack — no heavy badge background,
    /// just a tinted glyph that reads clearly at small menu sizes.
    private func comboPackIcon(for pack: ComboSoundPack) -> NSImage? {
        let (symbol, color): (String, NSColor) = {
            switch pack.id {
            case "classic":  return ("star.fill",                   .systemYellow)
            case "loadout":  return ("scope",                       .systemRed)
            case "chaos":    return ("theatermasks.fill",            .systemPurple)
            case "soft":     return ("heart.fill",                   .systemPink)
            case "desi-mix": return ("globe.asia.australia.fill",    .systemTeal)
            default:         return ("square.stack.fill",            .systemGray)
            }
        }()
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        return NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
    }

    private func updateSoundMenuItem() {
        soundToggleMenuItem?.state = soundPlayer.isEnabled ? .on : .off
    }

    private func updateMouseClickSoundMenuItem() {
        mouseClickSoundToggleMenuItem?.state = soundPlayer.isMouseClickSoundEnabled ? .on : .off
    }

    private func updateComboSoundMenuItem() {
        comboSoundToggleMenuItem?.state = soundPlayer.isComboSoundEnabled ? .on : .off
    }

    /// A minimal SF Symbol rendered as a template image — adapts automatically
    /// to dark and light menu backgrounds, matching the system macOS menu style.
    private func makeMenuIcon(symbol: String, pointSize: CGFloat = 13) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        guard let img = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return nil }
        img.isTemplate = true
        return img
    }

    /// Small coloured dot used as the status indicator next to the live status line.
    private func makeStatusDot(active: Bool) -> NSImage {
        let diameter: CGFloat = 7
        let size = NSSize(width: diameter, height: diameter)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }
        let color: NSColor = active ? .systemGreen : .systemOrange
        let path = NSBezierPath(ovalIn: NSRect(origin: .zero, size: size))
        color.setFill()
        path.fill()
        return image
    }

    /// Uppercase, small, tertiary-coloured section header — identical in style to
    /// native macOS section dividers (e.g. Finder sidebar, System Settings).
    private func makeSectionHeader(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        item.isEnabled = false
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor.tertiaryLabelColor,
            .kern: 0.6
        ]
        item.attributedTitle = NSAttributedString(string: title.uppercased(), attributes: attrs)
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
