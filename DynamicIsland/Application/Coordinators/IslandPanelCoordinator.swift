import AppKit
import SwiftUI

@MainActor
final class IslandPanelCoordinator {
    private(set) var panel: IslandPanel?
    private let keyboardMonitor: GlobalKeystrokeMonitor
    private let keystrokeStore: KeystrokePanelStore
    private let musicManager: MusicManager
    private let hitState: IslandHitState
    private let onOpenSettings: () -> Void

    private var mouseMonitor: Any?
    private var mousePollTimer: Timer?

    init(
        keyboardMonitor: GlobalKeystrokeMonitor,
        keystrokeStore: KeystrokePanelStore,
        musicManager: MusicManager,
        hitState: IslandHitState,
        onOpenSettings: @escaping () -> Void
    ) {
        self.keyboardMonitor = keyboardMonitor
        self.keystrokeStore = keystrokeStore
        self.musicManager = musicManager
        self.hitState = hitState
        self.onOpenSettings = onOpenSettings
    }

    func installPanel() {
        let host = NSHostingView(rootView: DynamicIslandView(
            keyboardMonitor: keyboardMonitor,
            keystrokeStore: keystrokeStore,
            musicManager: musicManager,
            hitState: hitState,
            onOpenSettings: onOpenSettings
        ))
        host.sizingOptions = []
        host.frame = NSRect(origin: .zero, size: IslandMetrics.panelSize)
        host.autoresizingMask = [.width, .height]

        let panel = IslandPanel.make(contentView: host)
        self.panel = panel

        refreshPresentation()
        hitState.onMousePolicyChanged = { [weak self] in self?.updatePanelMouseIgnore() }
        startMouseTracking()
        updatePanelMouseIgnore()
    }

    func tearDown() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        mousePollTimer?.invalidate()
        mousePollTimer = nil
    }

    func refreshPresentation() {
        guard let panel else { return }
        if let screen = targetScreen() {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0
                context.allowsImplicitAnimation = false
                panel.reposition(on: screen)
            }
        }
        panel.orderFrontRegardless()
        updatePanelMouseIgnore()
    }

    func handleActiveSpaceDidChange() {
        refreshPresentation()
        DispatchQueue.main.async { [weak self] in
            self?.refreshPresentation()
        }
    }

    private func targetScreen() -> NSScreen? {
        NSScreen.main ?? NSScreen.screens.first
    }

    private func pillScreenRect() -> NSRect? {
        guard let panel else { return nil }
        let f = panel.frame
        let sz = hitState.compactHitSize
        let pw = sz.width
        let ph = sz.height
        return NSRect(
            x: f.midX - pw / 2 - 10,
            y: f.maxY - ph - 8,
            width: pw + 20,
            height: ph + 8
        )
    }

    private func updatePanelMouseIgnore() {
        guard let panel else { return }
        let over = pillScreenRect()?.contains(NSEvent.mouseLocation) ?? false
        let shouldIgnore = !over && !hitState.isHoverExpanded
        if panel.ignoresMouseEvents != shouldIgnore {
            panel.ignoresMouseEvents = shouldIgnore
        }
    }

    private func startMouseTracking() {
        let mask: NSEvent.EventTypeMask = [
            .mouseMoved, .leftMouseDragged, .rightMouseDragged,
            .leftMouseDown, .rightMouseDown, .otherMouseDown,
        ]
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            self?.updatePanelMouseIgnore()
        }

        if mouseMonitor == nil {
            mousePollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
                self?.updatePanelMouseIgnore()
            }
        }
    }
}
