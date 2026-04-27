//
//  IslandPanelBackground.swift
//  DynamicIsland
//

import SwiftUI

enum IslandPanelBackground {
    @ViewBuilder
    static func notchPanel(cornerRadius: CGFloat = 14) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.075),
                        Color.white.opacity(0.032),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.105), lineWidth: 1)
            )
    }

    @ViewBuilder
    static func notchSubpanel(cornerRadius: CGFloat = 11) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.047))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.082), lineWidth: 1)
            )
    }
}

#Preview("Panel chrome") {
    VStack(alignment: .leading, spacing: 12) {
        Text("Notch panel")
            .font(.headline)
            .foregroundStyle(.white)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(IslandPanelBackground.notchPanel(cornerRadius: 15))

        Text("Subpanel")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.7))
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(IslandPanelBackground.notchSubpanel(cornerRadius: 12))
    }
    .padding(20)
    .frame(width: 320)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
