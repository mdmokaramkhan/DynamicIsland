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
    // Collapsed footprint — intentionally a hair smaller than the real
    // MacBook notch (~200 x 32 pt) so the idle pill tucks behind the
    // hardware cutout on notched displays and disappears until hover.
    private let collapsedSize = CGSize(width: 150, height: 30)
    private let collapsedTopRadius: CGFloat = 10
    private let collapsedBottomRadius: CGFloat = 12

    // Expanded footprint — must not exceed `IslandMetrics.panelSize` since
    // the panel clips to its own bounds.
    private let expandedSize = CGSize(width: 380, height: 90)
    private let expandedTopRadius: CGFloat = 10
    private let expandedBottomRadius: CGFloat = 22

    private let hoverAnimation = Animation.spring(response: 0.45, dampingFraction: 0.78)
    private let inputExpansionDuration: TimeInterval = 1.5

    @ObservedObject var keyboardMonitor: GlobalKeystrokeMonitor
    @ObservedObject var keystrokeStore: KeystrokeStreamStore
    @State private var isHovering = false
    @State private var isExpandedByInput = false
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
                    .frame(width: currentSize.width,
                           height: currentSize.height)

                if isExpanded {
                    islandExpandedContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 10)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .onHover { hovering in
                isHovering = hovering
            }
            .onChange(of: keystrokeStore.tokens) { updatedTokens in
                guard !updatedTokens.isEmpty else { return }
                triggerInputExpansion()
            }
            .onDisappear {
                collapseWorkItem?.cancel()
                collapseWorkItem = nil
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(hoverAnimation, value: isHovering)
    }

    private var currentSize: CGSize {
        isExpanded ? expandedSize : collapsedSize
    }

    private var currentTopRadius: CGFloat {
        isExpanded ? expandedTopRadius : collapsedTopRadius
    }

    private var currentBottomRadius: CGFloat {
        isExpanded ? expandedBottomRadius : collapsedBottomRadius
    }

    private var isExpanded: Bool {
        isHovering || isExpandedByInput
    }

    @ViewBuilder
    private var islandExpandedContent: some View {
        if !keystrokeStore.tokens.isEmpty {
            keystrokeStream
        } else if !keyboardMonitor.fallbackMessage.isEmpty {
            Text(keyboardMonitor.fallbackMessage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.88))
                .multilineTextAlignment(.center)
        }
    }

    private var keystrokeStream: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(keystrokeStore.tokens) { token in
                        KeystrokeChipView(token: token)
                            .id(token.id)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 2)
            }
            .onAppear {
                scrollToLatestChip(with: proxy)
            }
            .onChange(of: keystrokeStore.tokens) { _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    scrollToLatestChip(with: proxy)
                }
            }
        }
    }

    private func triggerInputExpansion() {
        isExpandedByInput = true

        collapseWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            withAnimation(hoverAnimation) {
                isExpandedByInput = false
            }
        }
        collapseWorkItem = workItem

        DispatchQueue.main.asyncAfter(deadline: .now() + inputExpansionDuration, execute: workItem)
    }

    private func scrollToLatestChip(with proxy: ScrollViewProxy) {
        guard let lastId = keystrokeStore.tokens.last?.id else { return }
        proxy.scrollTo(lastId, anchor: .trailing)
    }
}

#Preview {
    DynamicIslandView(
        keyboardMonitor: GlobalKeystrokeMonitor(),
        keystrokeStore: KeystrokeStreamStore()
    )
        .frame(width: 380, height: 90)
        .background(Color.gray.opacity(0.2))
}
