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
    // Panel width matches boringNotch openNotchSize.width (640pt).
    // Height must cover the largest hover-expanded layout; locking the NSPanel to
    // this size avoids NSHostingView↔window constraint feedback (crash in
    // _postWindowNeedsUpdateConstraints). Do not set smaller than that content.
    static let panelSize = CGSize(width: 640, height: 700)

    // Collapsed pill — must match DynamicIslandView.collapsedSize (click-through).
    static let collapsedSize = CGSize(width: 190, height: 30)

    // Horizontal margin kept from the top edge; notch-equipped displays get 0
    // so the pill sits flush with the top of the screen and visually covers
    // the notch. Non-notch displays sit just below the menu bar.
    static let topMarginNoNotch: CGFloat = 0
}

// MARK: - Hit-state bridge

/// Lightweight mutable reference that SwiftUI writes on every display-mode
/// change. AppDelegate observes via the callback to toggle the panel's
/// `ignoresMouseEvents` — the only compositor-level way to allow clicks to
/// fall through a transparent overlay window to the apps beneath it.
/// Only the hover-expanded tab panel uses the full window hit area; idle and
/// compact strip constrain hits to `compactHitSize` at the top center.
final class IslandHitState {
    /// True only for the hover-opened tab panel. That mode needs the full window
    /// to receive mouse events (controls + reliable `onHover(false)` to collapse).
    /// Compact idle / keystroke strip must stay click-through outside the pill.
    var isHoverExpanded: Bool = false {
        didSet {
            guard isHoverExpanded != oldValue else { return }
            notifyMousePolicyChanged()
        }
    }
    /// Centered hit target at the top of the panel when not hover-expanded.
    var compactHitSize: CGSize = IslandMetrics.collapsedSize {
        didSet {
            guard compactHitSize != oldValue else { return }
            notifyMousePolicyChanged()
        }
    }
    /// Called when hover-expanded or compact hit metrics change.
    var onMousePolicyChanged: (() -> Void)?

    private func notifyMousePolicyChanged() {
        onMousePolicyChanged?()
    }
}

// MARK: - Panel

final class IslandPanel: NSPanel {
    // Must be true so SwiftUI TextFields inside the island can receive
    // keyboard input when the user explicitly clicks into them.
    // The .nonactivatingPanel style mask ensures the panel doesn't
    // steal focus from other apps on mouse-over — only on explicit click.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    static func make(contentView: NSView) -> IslandPanel {
        let panelRect = NSRect(origin: .zero, size: IslandMetrics.panelSize)

        let panel = IslandPanel(
            contentRect: panelRect,
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
        panel.isRestorable = false
        // Start fully click-through; AppDelegate's mouse monitor re-enables
        // interaction only when the cursor enters the collapsed pill area.
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
        ]

        contentView.frame = panelRect
        contentView.autoresizingMask = [.width, .height]
        panel.contentView = contentView
        // Fixed content size: prevents SwiftUI’s NSHostingView from animating
        // the window frame to match intrinsic size (safe area / constraint loop).
        let fixed = IslandMetrics.panelSize
        panel.setContentSize(fixed)
        panel.contentMinSize = fixed
        panel.contentMaxSize = fixed
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
