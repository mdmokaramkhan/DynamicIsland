//
//  IslandTabView.swift
//  DynamicIsland
//

import SwiftUI

private enum IslandAppStorageDefaults {
    static let musicControlSlotsData: Data =
        (try? JSONEncoder().encode(MusicControlButton.defaultLayout)) ?? Data()
}

struct IslandTabView: View {
    @ObservedObject var keyboardMonitor: GlobalKeystrokeMonitor
    @Binding var isComposingTask: Bool
    @ObservedObject private var musicManager = MusicManager.shared
    @ObservedObject private var permissions = PermissionManager.shared

    @AppStorage("island.selectedTab") private var selectedTabRaw: String = IslandTab.media.rawValue
    @AppStorage("island.musicControlSlots.v1") private var musicControlSlotsData: Data = IslandAppStorageDefaults.musicControlSlotsData

    private var selectedTab: IslandTab {
        IslandTab(rawValue: selectedTabRaw) ?? .media
    }

    @State private var tasks: [IslandTask] = TaskStorage.load()
    @State private var focusPandoraMinutes: Int = 25
    @State private var focusPandoraRemainingSec: Int = 25 * 60
    @State private var focusPandoraIsRunning: Bool = false
    @State private var focusPandoraPulse: Bool = false

    @Namespace private var tabAnimation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            tabBarView

            ZStack(alignment: .top) {
                if selectedTab == .media {
                    IslandNowPlayingView(musicManager: musicManager, musicControlSlots: musicControlSlots)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                } else if selectedTab == .tasks {
                    IslandTasksTabView(tasks: $tasks, isComposingTask: $isComposingTask)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                } else if selectedTab == .focusPandora {
                    IslandFocusTabView(
                        focusPandoraMinutes: $focusPandoraMinutes,
                        focusPandoraRemainingSec: $focusPandoraRemainingSec,
                        focusPandoraIsRunning: $focusPandoraIsRunning,
                        focusPandoraPulse: $focusPandoraPulse
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                } else if selectedTab == .settings {
                    IslandSettingsView(
                        keyboardMonitor: keyboardMonitor,
                        permissions: permissions,
                        musicManager: musicManager,
                        musicControlSlotsData: $musicControlSlotsData,
                        focusPandoraMinutes: focusPandoraMinutes
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear {
            if IslandTab(rawValue: selectedTabRaw) == nil {
                DispatchQueue.main.async {
                    selectedTabRaw = IslandTab.media.rawValue
                }
            }
        }
        .onChange(of: selectedTabRaw) { _, new in
            if new != IslandTab.tasks.rawValue, isComposingTask {
                isComposingTask = false
            }
        }
    }

    private var musicControlSlots: [MusicControlButton] {
        let decoded = (try? JSONDecoder().decode([MusicControlButton].self, from: musicControlSlotsData))
            ?? MusicControlButton.defaultLayout
        return normalizedMusicControlSlots(decoded)
    }

    private func normalizedMusicControlSlots(_ slots: [MusicControlButton]) -> [MusicControlButton] {
        let fixedCount = 5
        if slots.count == fixedCount {
            return slots
        }
        if slots.count > fixedCount {
            return Array(slots.prefix(fixedCount))
        }
        return slots + Array(repeating: .none, count: fixedCount - slots.count)
    }

    // MARK: - Tab bar (boringNotch TabSelectionView style)

    private var tabBarView: some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(IslandTab.allCases.filter { $0 != .settings }, id: \.self) { tab in
                    tabIconButton(tab)
                }
            }
            .clipShape(Capsule())

            Spacer(minLength: 0)

            HStack(spacing: 0) {
                tabIconButton(.settings)
            }
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, minHeight: 26, maxHeight: 26, alignment: .leading)
    }

    private func tabIconButton(_ tab: IslandTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(.smooth) { selectedTabRaw = tab.rawValue }
        } label: {
            Image(systemName: tab.icon)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .symbolRenderingMode(.hierarchical)
                .padding(.horizontal, 13)
                .frame(height: 26)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.38))
        .background {
            if isSelected {
                Capsule()
                    .fill(Color.white.opacity(0.13))
                    .matchedGeometryEffect(id: "tabCapsule", in: tabAnimation)
            } else {
                Capsule()
                    .fill(Color.clear)
                    .matchedGeometryEffect(id: "tabCapsule", in: tabAnimation)
                    .hidden()
            }
        }
    }
}

#Preview("Island tab bar") {
    @Previewable @State var composing = false
    IslandTabView(keyboardMonitor: GlobalKeystrokeMonitor(), isComposingTask: $composing)
        .frame(width: 440, alignment: .topLeading)
        .padding(16)
        .background(Color.black)
        .preferredColorScheme(.dark)
}
