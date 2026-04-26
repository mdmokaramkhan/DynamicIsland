//
//  IslandPanel.swift
//  DynamicIsland
//
//  A borderless, non-activating NSPanel that floats above the menu bar and
//  hosts the dynamic-island pill. The panel's frame is sized to the expanded
//  bounds so the pill has a stable hit-area while it animates inside.
//

import AppKit

enum IslandMetrics {
    // The panel is sized to the fully-expanded pill so the hit area never
    // changes; the pill shrinks *inside* the panel on hover-out.
    static let panelSize = CGSize(width: 420, height: 90)

    // Horizontal margin kept from the top edge; notch-equipped displays get 0
    // so the pill sits flush with the top of the screen and visually covers
    // the notch. Non-notch displays sit just below the menu bar.
    static let topMarginNoNotch: CGFloat = 0
}

final class IslandPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    static func make(contentView: NSView) -> IslandPanel {
        let panel = IslandPanel(
            contentRect: NSRect(origin: .zero, size: IslandMetrics.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
        ]

        panel.contentView = contentView
        panel.acceptsMouseMovedEvents = true

        return panel
    }

    /// Repositions the panel at the top-center of `screen`, anchored to the
    /// notch if present, otherwise just below the menu bar.
    func reposition(on screen: NSScreen) {
        let screenFrame = screen.frame
        let size = IslandMetrics.panelSize

        let originX = screenFrame.midX - size.width / 2

        // `safeAreaInsets.top` is > 0 on notched displays (macOS 12+).
        let notchInset: CGFloat
        if #available(macOS 12.0, *) {
            notchInset = screen.safeAreaInsets.top
        } else {
            notchInset = 0
        }

        // In AppKit the origin is bottom-left, so Y is measured from the
        // bottom of the screen. We want the top of the panel to align with
        // either the top edge (notch) or just under the menu bar.
        let topOffset: CGFloat
        if notchInset > 0 {
            topOffset = 0
        } else {
            topOffset = NSStatusBar.system.thickness + IslandMetrics.topMarginNoNotch
        }

        let originY = screenFrame.maxY - size.height - topOffset

        setFrame(NSRect(origin: CGPoint(x: originX, y: originY), size: size),
                 display: true)
    }
}
