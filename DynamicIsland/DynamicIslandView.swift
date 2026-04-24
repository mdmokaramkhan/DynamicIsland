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

    @State private var isHovering = false

    var body: some View {
        // Top-anchored so the pill hugs the notch / menu bar regardless of
        // its current height. The panel itself is already pinned to the top
        // of the screen.
        VStack(spacing: 0) {
            NotchShape(topRadius: currentTopRadius,
                       bottomRadius: currentBottomRadius)
                .fill(Color.black)
                .frame(width: currentSize.width,
                       height: currentSize.height)
                .onHover { hovering in
                    isHovering = hovering
                }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(hoverAnimation, value: isHovering)
    }

    private var currentSize: CGSize {
        isHovering ? expandedSize : collapsedSize
    }

    private var currentTopRadius: CGFloat {
        isHovering ? expandedTopRadius : collapsedTopRadius
    }

    private var currentBottomRadius: CGFloat {
        isHovering ? expandedBottomRadius : collapsedBottomRadius
    }
}

#Preview {
    DynamicIslandView()
        .frame(width: 380, height: 90)
        .background(Color.gray.opacity(0.2))
}
