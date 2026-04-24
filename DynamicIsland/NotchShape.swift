//
//  NotchShape.swift
//  DynamicIsland
//
//  Silhouette that matches the Macbook Notch shape:
//  full-width flat top edge flush against the bezel, concave "wing" curves
//  at the top corners (quadratic bezier, control point on the top edge) that
//  flow into inset vertical sides, straight sides, and larger quadratic
//  rounded corners at the bottom.
//
//  Both corner radii are exposed through `animatableData` so hover
//  transitions interpolate smoothly.
//

import SwiftUI

struct NotchShape: Shape {
    /// Inset of the vertical sides from the left/right edges at the top,
    /// and depth of the concave wing curve at each top corner.
    var topRadius: CGFloat

    /// Radius of the rounded corners at the bottom-left / bottom-right.
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let maxR = max(0, min(rect.width / 2, rect.height / 2))
        let tr = max(0, min(topRadius, maxR))
        let br = max(0, min(bottomRadius, maxR - tr))

        var path = Path()

        // Start at the top-left outer corner (flush with the bezel).
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        // Top-left wing: quadratic curve from outer top-left corner inward to
        // the top of the left side wall. Control point on the top edge pulls
        // the curve outward — this is the concave "notch wing" shape.
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + tr, y: rect.minY + tr),
            control: CGPoint(x: rect.minX + tr, y: rect.minY)
        )

        // Left side wall, straight down.
        path.addLine(to: CGPoint(x: rect.minX + tr, y: rect.maxY - br))

        // Bottom-left rounded corner.
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + tr + br, y: rect.maxY),
            control: CGPoint(x: rect.minX + tr, y: rect.maxY)
        )

        // Flat bottom edge.
        path.addLine(to: CGPoint(x: rect.maxX - tr - br, y: rect.maxY))

        // Bottom-right rounded corner.
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - tr, y: rect.maxY - br),
            control: CGPoint(x: rect.maxX - tr, y: rect.maxY)
        )

        // Right side wall, straight up.
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY + tr))

        // Top-right wing: mirror of the top-left.
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - tr, y: rect.minY)
        )

        // Flat top edge back to the start.
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))

        return path
    }
}

#Preview {
    NotchShape(topRadius: 12, bottomRadius: 22)
        .fill(Color.black)
        .frame(width: 380, height: 90)
        .padding()
        .background(Color.gray.opacity(0.2))
}
