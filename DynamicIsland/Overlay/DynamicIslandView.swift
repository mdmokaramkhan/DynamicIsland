//
//  DynamicIslandView.swift
//

import SwiftUI

struct DynamicIslandView: View {
    private enum DisplayMode {
        case idle
        case hoverExpanded
        case keystrokeExpanded
    }

    // MARK: - Sizes

    private let collapsedSize = CGSize(width: 190, height: 30)
    private let collapsedTopRadius: CGFloat = 6
    private let collapsedBottomRadius: CGFloat = 14

    private let keystrokeWidth: CGFloat = 288
    private let keystrokeContentHeight: CGFloat = 20

    private let hoverExpandedWidth: CGFloat = 640

    private let expandedContentInset = EdgeInsets(top: 8, leading: 30, bottom: 24, trailing: 30)

    private let expandedTopRadius: CGFloat = 19
    private let expandedBottomRadius: CGFloat = 24

    private let keystrokePillTopRadius: CGFloat = 5
    private let keystrokePillBottomRadius: CGFloat = 18

    // MARK: - Animation (UNIFIED)

    private let islandSpring = Animation.interpolatingSpring(
        mass: 0.8,
        stiffness: 220,
        damping: 22
    )

    private let stripFade = Animation.easeInOut(duration: 0.22)

    private let hoverOpenDelay: UInt64 = 180_000_000
    private let hoverCloseDelay: UInt64 = 100_000_000

    private let inputExpansionDuration: TimeInterval = 1.5

    // MARK: - Dependencies

    @ObservedObject var keyboardMonitor: GlobalKeystrokeMonitor
    @ObservedObject var keystrokeStore: KeystrokePanelStore
    @ObservedObject var musicManager: MusicManager
    @ObservedObject private var focusTimer = FocusPandoraTimer.shared

    let hitState: IslandHitState
    var onOpenSettings: () -> Void = {}

    @AppStorage(AppSettings.Key.selectedTab) private var selectedTabRaw: String = IslandTab.media.rawValue
    @AppStorage(AppSettings.Key.appearanceShadow) private var dropShadow: Bool = true

    // MARK: - State

    @State private var displayMode: DisplayMode = .idle
    @State private var isHovering = false
    @State private var isExpandedByInput = false
    @State private var isComposingTask = false

    @State private var hoverTask: Task<Void, Never>?
    @State private var collapseWorkItem: DispatchWorkItem?

    @State private var hapticTrigger = false

    // 🔥 NEW SMOOTH SCALE SYSTEM
    @State private var hoverScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 0) {
            islandPill
                .onHover { handleHover($0) }
                .sensoryFeedback(.alignment, trigger: hapticTrigger)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Island Pill

    private var islandPill: some View {
        VStack(spacing: 0) {
            if displayMode != .idle {
                islandModeContent
            }
        }
        .frame(
            width: currentWidth,
            height: displayMode == .idle ? collapsedSize.height : nil
        )
        .background(
            ZStack {
                if dropShadow && displayMode != .idle {
                    NotchShape(topRadius: currentTopRadius, bottomRadius: currentBottomRadius)
                        .fill(Color.black.opacity(0.45))
                        .blur(radius: 16)
                        .offset(y: 8)
                }

                NotchShape(topRadius: currentTopRadius, bottomRadius: currentBottomRadius)
                    .fill(Color.black)
            }
        )
        .clipShape(
            NotchShape(topRadius: currentTopRadius, bottomRadius: currentBottomRadius)
        )
        .scaleEffect(hoverScale)
        .compositingGroup()
        .drawingGroup()
        .animation(islandSpring, value: displayMode)
        .animation(islandSpring, value: hoverScale)
    }

    // MARK: - Content

    @ViewBuilder
    private var islandModeContent: some View {
        if displayMode == .keystrokeExpanded {
            compactKeystrokeStrip
                .frame(height: keystrokeContentHeight)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        } else if displayMode == .hoverExpanded {
            IslandTabView(
                keyboardMonitor: keyboardMonitor,
                isComposingTask: $isComposingTask,
                onOpenSettings: onOpenSettings
            )
            .padding(expandedContentInset)
        }
    }

    // MARK: - Strip

    private var compactKeystrokeStrip: some View {
        HStack {
            appIconView
            Spacer()
            if let token = keystrokeStore.lastKeystrokeToken {
                KeystrokeChipView(token: token)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(stripFade, value: keystrokeStore.lastKeystrokeToken)
    }

    @ViewBuilder
    private var appIconView: some View {
        if let icon = keystrokeStore.frontmostAppIcon {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Sizes

    private var currentWidth: CGFloat {
        switch displayMode {
        case .idle: return collapsedSize.width
        case .hoverExpanded: return hoverExpandedWidth
        case .keystrokeExpanded: return keystrokeWidth
        }
    }

    private var currentTopRadius: CGFloat {
        displayMode == .idle ? collapsedTopRadius :
        displayMode == .hoverExpanded ? expandedTopRadius : keystrokePillTopRadius
    }

    private var currentBottomRadius: CGFloat {
        displayMode == .idle ? collapsedBottomRadius :
        displayMode == .hoverExpanded ? expandedBottomRadius : keystrokePillBottomRadius
    }

    // MARK: - Hover Logic (FIXED)

    private func handleHover(_ hovering: Bool) {
        hoverTask?.cancel()

        if hovering {

            isHovering = true
            hapticTrigger.toggle()

            // 🔥 Smooth scale impulse
            withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.5)) {
                hoverScale = 1.05
            }

            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.08)) {
                hoverScale = 1.0
            }

            hoverTask = Task {
                try? await Task.sleep(nanoseconds: hoverOpenDelay)
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(islandSpring) {
                        displayMode = .hoverExpanded
                    }
                }
            }

        } else {

            hoverTask = Task {
                try? await Task.sleep(nanoseconds: hoverCloseDelay)
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(islandSpring) {
                        displayMode = .idle
                        hoverScale = 1.0
                    }
                }
            }
        }
    }
}

#Preview {
    DynamicIslandView(
        keyboardMonitor: GlobalKeystrokeMonitor(),
        keystrokeStore: KeystrokePanelStore(),
        musicManager: MusicManager.shared,
        hitState: IslandHitState(),
        onOpenSettings: {}
    )
    .frame(width: 680, height: 400)
    .background(Color.gray.opacity(0.2))
}
