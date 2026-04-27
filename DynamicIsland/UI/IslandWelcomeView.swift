//
//  IslandWelcomeView.swift
//  DynamicIsland
//
//  Onboarding / hero panel (not currently wired to a tab).
//

import SwiftUI

struct IslandWelcomeView: View {
    @ObservedObject var keyboardMonitor: GlobalKeystrokeMonitor
    @Binding var selectedTabRaw: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            welcomeHeroBlock
            welcomeFeatureStrip
            welcomeStatusStrip
            welcomeFooterStrip
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(IslandPanelBackground.notchPanel(cornerRadius: 15))
    }

    private var welcomeHeroBlock: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .stroke(IslandChrome.heroRing, lineWidth: 1)
                    .frame(width: 44, height: 44)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.32, green: 0.55, blue: 0.95).opacity(0.35),
                                Color.white.opacity(0.08),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 38, height: 38)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )
                Image(systemName: "sparkles.2")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color(white: 0.82)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Dynamic Island")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                    Text(appVersionLabel)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.10))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )
                }
                Text("Menu-bar control for keys, tasks, and focus.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(IslandChrome.subtext)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 5) {
                Circle()
                    .fill(welcomeStatusColor)
                    .frame(width: 5, height: 5)
                Text("Live")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Color.white.opacity(0.68))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.white.opacity(0.06)))
            .overlay(Capsule().stroke(Color.white.opacity(0.09), lineWidth: 1))
        }
    }

    private var welcomeFeatureStrip: some View {
        HStack(spacing: 5) {
            welcomeFeatureCell(icon: "keyboard", title: "Keys")
            welcomeFeatureCell(icon: "checklist", title: "Tasks")
            welcomeFeatureCell(icon: "menubar.rectangle", title: "HUD")
            welcomeFeatureCell(icon: "timer", title: "Focus")
        }
    }

    private func welcomeFeatureCell(icon: String, title: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.78))
                .symbolRenderingMode(.hierarchical)
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.72))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 7)
        .background(IslandPanelBackground.notchSubpanel(cornerRadius: 10))
    }

    private var welcomeStatusStrip: some View {
        HStack(spacing: 7) {
            HStack(spacing: 6) {
                Circle()
                    .fill(welcomeStatusColor)
                    .frame(width: 5, height: 5)
                    .shadow(color: welcomeStatusColor.opacity(0.5), radius: 3, x: 0, y: 0)
                Text(keyboardMonitor.statusLine)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.75))
            }
            Spacer(minLength: 0)
            if case .missingAccessibility = keyboardMonitor.authorization {
                Button {
                    keyboardMonitor.openAccessibilitySettings()
                } label: {
                    HStack(spacing: 3) {
                        Text("Open settings")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color.orange.opacity(0.95))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(IslandPanelBackground.notchSubpanel(cornerRadius: 10))
    }

    private var welcomeStatusColor: Color {
        switch keyboardMonitor.authorization {
        case .authorized:
            return Color.mint
        case .missingAccessibility:
            return Color.orange
        }
    }

    private var welcomeFooterStrip: some View {
        HStack(spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTabRaw = IslandTab.focusPandora.rawValue
                }
            } label: {
                welcomeFooterPill(icon: "timer", title: "Start focus")
            }
            .buttonStyle(.plain)

            welcomeCreatorCard
        }
    }

    private var welcomeCreatorCard: some View {
        Link(destination: URL(string: "https://github.com/mdmokaramkhan")!) {
            welcomeFooterPill(icon: "person.crop.circle", title: "GitHub", isLink: true)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func welcomeFooterPill(icon: String, title: String, isLink: Bool = false) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .rounded))
            Spacer(minLength: 0)
            if isLink {
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 8, weight: .bold))
            }
        }
        .foregroundStyle(isLink ? IslandChrome.linkAccent : Color.white.opacity(0.78))
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Capsule()
                .fill(isLink ? IslandChrome.linkAccent.opacity(0.08) : Color.white.opacity(0.06))
        )
        .overlay(
            Capsule()
                .stroke(isLink ? IslandChrome.linkAccent.opacity(0.2) : Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var appVersionLabel: String {
        let s = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return s.map { "v\($0)" } ?? "v—"
    }
}

#Preview("Welcome") {
    @Previewable @State var selectedTab = IslandTab.media.rawValue
    IslandWelcomeView(keyboardMonitor: GlobalKeystrokeMonitor(), selectedTabRaw: $selectedTab)
        .frame(width: 400, alignment: .leading)
        .padding(16)
        .background(Color.black)
        .preferredColorScheme(.dark)
}
