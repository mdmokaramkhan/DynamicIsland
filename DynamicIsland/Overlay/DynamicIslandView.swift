//
//  DynamicIslandView.swift
//  DynamicIsland
//
//  The black notch-shaped view that lives inside the island panel.
//  Width is mode-specific. Height is:
//    • idle / keystroke  → fixed (compact pill)
//    • hover-expanded    → content-driven (island grows to fit)
//
//  Interaction model mirrors boringNotch:
//    • Hover enter → 150 ms wait → expand  (Task-debounced)
//    • Hover exit  → 100 ms wait → collapse (Task-debounced)
//    • Haptic feedback on hover enter when idle
//    • Open  animation: .spring(.bouncy(0.4)) / timingCurve fallback
//    • Close animation: overdamped spring (no bounce on collapse)
//    • Drop shadow only while expanded
//
//  The idle pill is strictly 190×30 — no transparent spacer, so the
//  black notch shape is exactly the pill height with nothing above it.
//

import SwiftUI

struct DynamicIslandView: View {
    private enum DisplayMode {
        case idle
        case hoverExpanded
        case keystrokeExpanded
    }

    // ── Sizes ────────────────────────────────────────────────────────────────
    private let collapsedSize = CGSize(width: 190, height: 30)
    private let keystrokeWidth: CGFloat = 288
    private let keystrokeContentHeight: CGFloat = 20
    // Open width — boringNotch openNotchSize.width = 640
    private let hoverExpandedWidth: CGFloat = 640
    // Inner safe area for expanded content. This keeps the UI away from the
    // curved notch border without adding an empty black spacer in idle state.
    private let expandedContentInset = EdgeInsets(top: 8, leading: 30, bottom: 24, trailing: 30)

    // ── Radii — boringNotch cornerRadiusInsets ───────────────────────────────
    // closed:  top = 6,  bottom = 14
    // opened:  top = 19, bottom = 24
    private let collapsedTopRadius: CGFloat     = 6
    private let collapsedBottomRadius: CGFloat  = 14
    private let expandedTopRadius: CGFloat      = 19
    private let expandedBottomRadius: CGFloat   = 24
    private let keystrokePillTopRadius: CGFloat = 6
    private let keystrokePillBottomRadius: CGFloat = 14

    // ── Animations ── mirrors boringNotch BoringAnimations + ContentView ─────
    // Open: bouncy spring (macOS 14+) or custom timing curve
    private var openAnimation: Animation {
        if #available(macOS 14.0, *) {
            return .spring(.bouncy(duration: 0.4))
        }
        return .timingCurve(0.16, 1, 0.3, 1, duration: 0.7)
    }
    // Close: overdamped spring — no bounce when collapsing
    private let closeAnimation = Animation.spring(
        response: 0.45, dampingFraction: 1.0, blendDuration: 0
    )

    private let inputExpansionDuration: TimeInterval = 1.5
    // Minimum hover dwell before expanding (ms) — like Defaults[.minimumHoverDuration]
    private let hoverOpenDelay: UInt64 = 150_000_000   // 150 ms
    // Debounce before collapsing on hover exit
    private let hoverCloseDelay: UInt64 = 100_000_000  // 100 ms

    // ── External state ────────────────────────────────────────────────────────
    @ObservedObject var keyboardMonitor: GlobalKeystrokeMonitor
    @ObservedObject var keystrokeStore: KeystrokePanelStore
    let hitState: IslandHitState

    // Mirror IslandTabView's persisted tab so the pill animates its height on tab switch
    @AppStorage("island.selectedTab") private var selectedTabRaw: String = IslandTab.welcome.rawValue

    // ── Internal state ────────────────────────────────────────────────────────
    @State private var isHovering = false
    @State private var isExpandedByInput = false
    @State private var isComposingTask = false
    @State private var displayMode: DisplayMode = .idle
    @State private var collapseWorkItem: DispatchWorkItem?
    // Async task handle for debounced hover open/close
    @State private var hoverTask: Task<Void, Never>?
    // Toggle to trigger haptic on hover-enter while idle
    @State private var hapticTrigger: Bool = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            islandPill
                .onHover { hovering in handleHover(hovering) }
                .onChange(of: keystrokeStore.lastKeystrokeToken) { updatedToken in
                    guard updatedToken != nil else { return }
                    triggerInputExpansion()
                }
                .onDisappear {
                    hoverTask?.cancel()
                    collapseWorkItem?.cancel()
                    collapseWorkItem = nil
                }
                .sensoryFeedback(.alignment, trigger: hapticTrigger)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: isComposingTask) { _, _ in
            withAnimation(isComposingTask ? openAnimation : closeAnimation) {
                recalculateDisplayMode()
            }
        }
    }

    // MARK: - Island pill

    @ViewBuilder
    private var islandPill: some View {
        VStack(spacing: 0) {
            // No transparent spacer here — the idle pill must be exactly
            // collapsedSize.height with no empty black region above content.
            // The notchAreaTopPad is applied as padding inside the content.
            if displayMode != .idle {
                islandModeContent
                    .transition(
                        .scale(scale: 0.85, anchor: .top)
                        .combined(with: .opacity)
                    )
            }
        }
        .frame(
            width: currentWidth,
            height: displayMode == .idle ? collapsedSize.height : nil
        )
        .background(
            NotchShape(topRadius: currentTopRadius, bottomRadius: currentBottomRadius)
                .fill(Color.black)
        )
        .clipShape(
            NotchShape(topRadius: currentTopRadius, bottomRadius: currentBottomRadius)
        )
        // Elevation shadow — only while expanded (matches boringNotch .shadow on open)
        .shadow(
            color: displayMode != .idle ? Color.black.opacity(0.65) : .clear,
            radius: 8, x: 0, y: 5
        )
        .animation(displayMode == .idle ? closeAnimation : openAnimation, value: displayMode)
        // Animate island height when tab content changes height
        .animation(.smooth(duration: 0.32), value: selectedTabRaw)
    }

    // MARK: - Mode content

    @ViewBuilder
    private var islandModeContent: some View {
        if displayMode == .keystrokeExpanded, let token = visibleKeystrokeToken {
            keystrokePanel(token: token)
                .frame(height: keystrokeContentHeight)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        } else if displayMode == .hoverExpanded {
            islandExpandedContent
                .padding(expandedContentInset)
        }
    }

    // MARK: - Expanded content

    @ViewBuilder
    private var islandExpandedContent: some View {
        if !keyboardMonitor.fallbackMessage.isEmpty {
            Text(keyboardMonitor.fallbackMessage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.88))
                .multilineTextAlignment(.center)
        } else {
            IslandTabView(
                keyboardMonitor: keyboardMonitor,
                isComposingTask: $isComposingTask
            )
        }
    }

    // MARK: - Keystroke panel

    private func keystrokePanel(token: KeystrokeToken) -> some View {
        HStack(spacing: 0) {
            appIconView
            Spacer(minLength: 8)
            KeystrokeChipView(token: token)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var appIconView: some View {
        if let appIcon = keystrokeStore.frontmostAppIcon {
            Image(nsImage: appIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.8))
                .frame(width: 20, height: 20)
        }
    }

    // MARK: - Mode metrics

    private var currentWidth: CGFloat {
        switch displayMode {
        case .idle:               return collapsedSize.width
        case .hoverExpanded:      return hoverExpandedWidth
        case .keystrokeExpanded:  return keystrokeWidth
        }
    }

    private var currentTopRadius: CGFloat {
        switch displayMode {
        case .idle:                return collapsedTopRadius
        case .hoverExpanded:       return expandedTopRadius
        case .keystrokeExpanded:   return keystrokePillTopRadius
        }
    }

    private var currentBottomRadius: CGFloat {
        switch displayMode {
        case .idle:                return collapsedBottomRadius
        case .hoverExpanded:       return expandedBottomRadius
        case .keystrokeExpanded:   return keystrokePillBottomRadius
        }
    }

    // MARK: - Hover interaction (mirrors boringNotch handleHover)

    private func handleHover(_ hovering: Bool) {
        hoverTask?.cancel()

        if hovering {
            // Immediately register hover for visual feedback
            withAnimation(openAnimation) { isHovering = true }

            // Fire haptic when cursor enters the closed pill
            if displayMode == .idle { hapticTrigger.toggle() }

            // Only open after the dwell delay and only from idle
            guard displayMode == .idle else { return }
            hoverTask = Task {
                try? await Task.sleep(nanoseconds: hoverOpenDelay)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard self.isHovering, self.displayMode == .idle else { return }
                    withAnimation(self.openAnimation) { self.recalculateDisplayMode() }
                }
            }
        } else {
            // Debounce collapse so brief mouse-out flickers don't close the panel
            hoverTask = Task {
                try? await Task.sleep(nanoseconds: hoverCloseDelay)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(self.closeAnimation) {
                        self.isHovering = false
                        self.recalculateDisplayMode()
                    }
                }
            }
        }
    }

    // MARK: - Keystroke expansion

    private var visibleKeystrokeToken: KeystrokeToken? {
        guard let token = keystrokeStore.lastKeystrokeToken,
              let lastKeystrokeAt = keystrokeStore.lastKeystrokeAt else { return nil }
        let age = Date().timeIntervalSince(lastKeystrokeAt)
        return age <= inputExpansionDuration ? token : nil
    }

    private func triggerInputExpansion() {
        guard displayMode == .idle else { return }

        withAnimation(openAnimation) {
            isExpandedByInput = true
            recalculateDisplayMode()
        }

        collapseWorkItem?.cancel()
        let workItem = DispatchWorkItem { [self] in
            withAnimation(closeAnimation) {
                isExpandedByInput = false
                recalculateDisplayMode()
            }
        }
        collapseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + inputExpansionDuration, execute: workItem)
    }

    // MARK: - State

    private func recalculateDisplayMode() {
        if isComposingTask {
            displayMode = .hoverExpanded
        } else if isHovering {
            displayMode = .hoverExpanded
        } else if isExpandedByInput {
            displayMode = .keystrokeExpanded
        } else {
            displayMode = .idle
        }
        hitState.isExpanded = displayMode != .idle
    }
}

#Preview {
    DynamicIslandView(
        keyboardMonitor: GlobalKeystrokeMonitor(),
        keystrokeStore: KeystrokePanelStore(),
        hitState: IslandHitState()
    )
    .frame(width: 680, height: 400)
    .background(Color.gray.opacity(0.2))
}
