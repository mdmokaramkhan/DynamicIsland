//
//  DynamicIslandView.swift
//  DynamicIsland
//
//  The black notch-shaped view that lives inside the island panel.
//  Width is mode-specific. Height is:
//    • idle / keystroke  → fixed (compact pill)
//    • hover-expanded    → content-driven (island grows to fit)
//
//  The NotchShape is used as a .background so SwiftUI sizes it to
//  match the content, not the other way around.
//
//  Expanded (hover) uses a wide 16∶10–style strip. Idle and keystroke use the
//  original compact pills — they are not forced to match that aspect ratio.
//

import SwiftUI

struct DynamicIslandView: View {
    private enum DisplayMode {
        case idle
        case hoverExpanded
        case keystrokeExpanded
    }

    // Collapsed + keystroke — original compact sizes (independent of expanded width)
    private let collapsedSize = CGSize(width: 190, height: 30)
    private let collapsedTopRadius: CGFloat = 5
    private let collapsedBottomRadius: CGFloat = 12

    private let keystrokeWidth: CGFloat = 288
    private let keystrokeContentHeight: CGFloat = 20

    // Wide hover strip; slightly under the previous 640pt target (~9% trim)
    private let hoverExpandedWidth: CGFloat = 580

    // Band above content that lines up with the camera housing
    private let notchAreaHeight: CGFloat = 30

    // Radii scaled for a wider sheet (hover)
    private let expandedTopRadius: CGFloat = 12
    private let expandedBottomRadius: CGFloat = 26

    // Keystroke strip: more capsule-like; smaller top (wings) so NotchShape
    // can apply a larger effective bottom corner within the short height
    private let keystrokePillTopRadius: CGFloat = 5
    private let keystrokePillBottomRadius: CGFloat = 18

    private let hoverAnimation = Animation.spring(response: 0.45, dampingFraction: 0.78)
    private let inputExpansionDuration: TimeInterval = 1.5

    @ObservedObject var keyboardMonitor: GlobalKeystrokeMonitor
    @ObservedObject var keystrokeStore: KeystrokePanelStore
    let hitState: IslandHitState
    @State private var isHovering = false
    @State private var isExpandedByInput = false
    @State private var displayMode: DisplayMode = .idle
    @State private var collapseWorkItem: DispatchWorkItem?

    var body: some View {
        VStack(spacing: 0) {
            islandPill
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

    // MARK: - Island pill

    // The VStack is the layout driver. Width is always constrained by mode.
    // For idle, height is pinned to collapsedSize.height. For expanded modes,
    // height is nil so SwiftUI measures the natural content height.
    @ViewBuilder
    private var islandPill: some View {
        VStack(spacing: 0) {
            // In hover-expanded mode, reserve the top notchAreaHeight of the
            // island for the hardware notch region (always black, no content).
            // This pushes all UI below the physical camera/sensor cutout.
            if displayMode == .hoverExpanded {
                Color.clear
                    .frame(height: notchAreaHeight)
            }

            if displayMode != .idle {
                islandModeContent
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 1.02, anchor: .top)),
                        removal: .opacity
                    ))
            }
        }
        .frame(
            width: currentWidth,
            height: displayMode == .idle ? collapsedSize.height : nil
        )
        // NotchShape fills whatever size the VStack produces — this is the
        // key change that makes the island height content-driven.
        .background(
            NotchShape(topRadius: currentTopRadius, bottomRadius: currentBottomRadius)
                .fill(Color.black)
        )
        .clipShape(
            NotchShape(topRadius: currentTopRadius, bottomRadius: currentBottomRadius)
        )
    }

    @ViewBuilder
    private var islandModeContent: some View {
        if displayMode == .keystrokeExpanded, let token = visibleKeystrokeToken {
            // Compact pill: icon + keystroke chip, vertically centred
            keystrokePanel(token: token)
                .frame(height: keystrokeContentHeight)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        } else if displayMode == .hoverExpanded {
            // Full panel: content is placed below the notch-area spacer
            islandExpandedContent
                .padding(.horizontal, 24)
                .padding(.bottom, 22)
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
            IslandTabView(keyboardMonitor: keyboardMonitor)
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
        case .idle:                 return collapsedTopRadius
        case .hoverExpanded:        return expandedTopRadius
        case .keystrokeExpanded:    return keystrokePillTopRadius
        }
    }

    private var currentBottomRadius: CGFloat {
        switch displayMode {
        case .idle:                 return collapsedBottomRadius
        case .hoverExpanded:        return expandedBottomRadius
        case .keystrokeExpanded:    return keystrokePillBottomRadius
        }
    }

    // MARK: - State management

    private var visibleKeystrokeToken: KeystrokeToken? {
        guard let token = keystrokeStore.lastKeystrokeToken,
              let lastKeystrokeAt = keystrokeStore.lastKeystrokeAt else {
            return nil
        }
        let age = Date().timeIntervalSince(lastKeystrokeAt)
        return age <= inputExpansionDuration ? token : nil
    }

    private func triggerInputExpansion() {
        // Only pop up the keystroke pill when the island is idle/collapsed.
        // If it is already visible (hover or a previous keystroke opened it),
        // there is no need to interrupt the user with a keystroke notification.
        guard displayMode == .idle else { return }

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
