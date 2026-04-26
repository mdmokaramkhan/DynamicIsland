//
//  IslandTabView.swift
//  DynamicIsland
//

import SwiftUI

// MARK: - Tabs
enum IslandTab: String, CaseIterable {
    case welcome = "Welcome"
    case activity = "Activity"

    var icon: String {
        switch self {
        case .welcome:
            return "sparkles"
        case .activity:
            return "keyboard"
        }
    }
}

struct IslandTabView: View {

    @ObservedObject var keyboardMonitor: GlobalKeystrokeMonitor
    @ObservedObject var keystrokeStore: KeystrokePanelStore

    @State private var selectedTab: IslandTab = .welcome

    private let inputExpansionDuration: TimeInterval = 1.5

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // 🔹 Tabs (FIXED POSITION)
            HStack(spacing: 8) {
                ForEach(IslandTab.allCases, id: \.self) { tab in
                    tabButton(tab)
                }
                Spacer()
            }
            .frame(height: 24) // 👈 prevents vertical jumping

            // 🔹 Content (DYNAMIC AREA)
            ZStack(alignment: .top) {
                switch selectedTab {
                case .welcome:
                    welcomeView

                case .activity:
                    activityView
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
    }

    // MARK: - Tab Button

    private func tabButton(_ tab: IslandTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 5) {

                Image(systemName: tab.icon)
                    .font(.system(size: 10, weight: .semibold))

                Text(tab.rawValue)
                    .font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(selectedTab == tab
                          ? Color.white.opacity(0.2)
                          : Color.white.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .stroke(
                        selectedTab == tab
                        ? Color.white.opacity(0.25)
                        : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.white.opacity(0.9))
    }

    // MARK: - Views

    private var welcomeView: some View {
        VStack(spacing: 5) {
            Text("Welcome to Dynamic Island")
                .font(.system(size: 11, weight: .semibold))

            Text("github.com/mdmokaramkhan")
                .font(.system(size: 10))
                .foregroundStyle(Color.white.opacity(0.7))
        }
        .foregroundStyle(Color.white)
    }

    @ViewBuilder
    private var activityView: some View {
        if let token = visibleKeystrokeToken {
            KeystrokeChipView(token: token)
        } else {
            Text("No recent activity")
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.7))
        }
    }

    // MARK: - Helper

    private var visibleKeystrokeToken: KeystrokeToken? {
        guard let token = keystrokeStore.lastKeystrokeToken,
              let last = keystrokeStore.lastKeystrokeAt else {
            return nil
        }

        let age = Date().timeIntervalSince(last)
        return age <= inputExpansionDuration ? token : nil
    }
}
