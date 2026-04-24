//
//  DynamicIslandView.swift
//  DynamicIsland
//
//  The black notch-shaped view that lives inside the island panel. The
//  shape animates its size and bottom corner radius on hover while the
//  subtle top flare stays fixed; the surrounding panel stays pinned to
//  the expanded bounds so the hover hit-area is stable.
//

import SwiftUI

struct DynamicIslandView: View {
    private enum DisplayMode {
        case idle
        case hoverExpanded
        case keystrokeExpanded
    }

    // Collapsed footprint — intentionally a hair smaller than the real
    // MacBook notch (~200 x 32 pt) so the idle pill tucks behind the
    // hardware cutout on notched displays and disappears until hover.
    private let collapsedSize = CGSize(width: 150, height: 30)
    private let collapsedTopRadius: CGFloat = 10
    private let collapsedBottomRadius: CGFloat = 12

    // Keystroke footprint — wider than idle but intentionally compact.
    private let keystrokeSize = CGSize(width: 286, height: 44)

    // Hover footprint — must not exceed `IslandMetrics.panelSize` since
    // the panel clips to its own bounds.
    private let hoverExpandedSize = CGSize(width: 380, height: 110)

    // Both expanded modes share the same radius spec so the pill edge looks
    // identical regardless of which mode triggered the expansion. NotchShape
    // clamps automatically when the height is smaller (keystroke mode).
    private let expandedTopRadius: CGFloat = 10
    private let expandedBottomRadius: CGFloat = 22

    private let hoverAnimation = Animation.spring(response: 0.45, dampingFraction: 0.78)
    private let inputExpansionDuration: TimeInterval = 1.5

    @ObservedObject var keyboardMonitor: GlobalKeystrokeMonitor
    @ObservedObject var keystrokeStore: KeystrokePanelStore
    @State private var isHovering = false
    @State private var isExpandedByInput = false
    @State private var displayMode: DisplayMode = .idle
    @State private var collapseWorkItem: DispatchWorkItem?

    var body: some View {
        // Top-anchored so the pill hugs the notch / menu bar regardless of
        // its current height. The panel itself is already pinned to the top
        // of the screen.
        VStack(spacing: 0) {
            ZStack(alignment: .center) {
                NotchShape(topRadius: currentTopRadius,
                           bottomRadius: currentBottomRadius)
                    .fill(Color.black)

                if displayMode != .idle {
                    islandExpandedContent
                        .padding(contentPadding)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            // The ZStack is sized to the current island footprint — content is
            // clipped to the notch shape so nothing bleeds outside the pill.
            .frame(width: currentSize.width, height: currentSize.height)
            .clipShape(NotchShape(topRadius: currentTopRadius,
                                  bottomRadius: currentBottomRadius))
            .onHover { hovering in
                isHovering = hovering
                recalculateDisplayMode()
            }
            .onChange(of: keystrokeStore.lastKeystrokeToken) { updatedToken in
                guard updatedToken != nil else { return }
                triggerInputExpansion()
            }
            .onDisappear {
                collapseWorkItem?.cancel()
                collapseWorkItem = nil
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(hoverAnimation, value: displayMode)
    }

    private var currentSize: CGSize {
        switch displayMode {
        case .idle:
            return collapsedSize
        case .hoverExpanded:
            return hoverExpandedSize
        case .keystrokeExpanded:
            return keystrokeSize
        }
    }

    private var currentTopRadius: CGFloat {
        switch displayMode {
        case .idle:              return collapsedTopRadius
        case .hoverExpanded,
             .keystrokeExpanded: return expandedTopRadius
        }
    }

    private var currentBottomRadius: CGFloat {
        switch displayMode {
        case .idle:              return collapsedBottomRadius
        case .hoverExpanded,
             .keystrokeExpanded: return expandedBottomRadius
        }
    }

    private var contentPadding: EdgeInsets {
        switch displayMode {
        case .idle:
            return EdgeInsets()
        case .hoverExpanded:
            return EdgeInsets(top: 24, leading: 16, bottom: 10, trailing: 16)
        case .keystrokeExpanded:
            // Match the hover horizontal inset exactly so content sits the
            // same distance from the curved edges in both expanded modes.
            return EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        }
    }

    @ViewBuilder
    private var islandExpandedContent: some View {
        if displayMode == .keystrokeExpanded, let token = visibleKeystrokeToken {
            keystrokePanel(token: token)
        } else if let token = visibleKeystrokeToken, displayMode == .hoverExpanded {
            KeystrokeChipView(token: token)
        } else if !keyboardMonitor.fallbackMessage.isEmpty {
            Text(keyboardMonitor.fallbackMessage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.88))
                .multilineTextAlignment(.center)
        } else {
            welcomeBadge
        }
    }

    private var welcomeBadge: some View {
        VStack(spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                Text("Welcome to Dynamic Island")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 11, weight: .semibold))
            }

            Link(destination: URL(string: "https://github.com/mdmokaramkhan")!) {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.system(size: 9, weight: .semibold))
                    Text("github.com/mdmokaramkhan")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundStyle(Color.white.opacity(0.9))
            }
        }
        .foregroundStyle(Color.white.opacity(0.95))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.20),
                            Color.white.opacity(0.10),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
        )
    }

    private var visibleKeystrokeToken: KeystrokeToken? {
        guard let token = keystrokeStore.lastKeystrokeToken,
              let lastKeystrokeAt = keystrokeStore.lastKeystrokeAt else {
            return nil
        }

        let age = Date().timeIntervalSince(lastKeystrokeAt)
        return age <= inputExpansionDuration ? token : nil
    }

    private func keystrokePanel(token: KeystrokeToken) -> some View {
        // Space-between: app icon pinned to the leading edge, keystroke chip
        // pinned to the trailing edge — both visually inside the island.
        HStack(spacing: 0) {
            appIconView
            Spacer(minLength: 8)
            KeystrokeChipView(token: token)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var appIconView: some View {
        if let appIcon = keystrokeStore.frontmostAppIcon {
            Image(nsImage: appIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.8))
                .frame(width: 20, height: 20)
        }
    }

    private func triggerInputExpansion() {
        isExpandedByInput = true
        recalculateDisplayMode()

        collapseWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            withAnimation(hoverAnimation) {
                isExpandedByInput = false
                recalculateDisplayMode()
            }
        }
        collapseWorkItem = workItem

        DispatchQueue.main.asyncAfter(deadline: .now() + inputExpansionDuration, execute: workItem)
    }

    private func recalculateDisplayMode() {
        if isHovering {
            displayMode = .hoverExpanded
        } else if isExpandedByInput {
            displayMode = .keystrokeExpanded
        } else {
            displayMode = .idle
        }
    }
}

#Preview {
    DynamicIslandView(
        keyboardMonitor: GlobalKeystrokeMonitor(),
        keystrokeStore: KeystrokePanelStore()
    )
        .frame(width: 380, height: 90)
        .background(Color.gray.opacity(0.2))
}
