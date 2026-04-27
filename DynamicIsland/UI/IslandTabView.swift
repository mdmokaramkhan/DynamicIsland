//
//  IslandTabView.swift
//  DynamicIsland
//

import SwiftUI

struct IslandTabView: View {
    @ObservedObject var keyboardMonitor: GlobalKeystrokeMonitor
    @Binding var isComposingTask: Bool
    @ObservedObject private var musicManager: MusicManager
    @ObservedObject private var permissions: PermissionManager
    @ObservedObject private var focusTimer: FocusPandoraTimer
    private let taskRepository: TaskRepository

    /// Opens the app settings in a standard window (not the island).
    var onOpenSettings: () -> Void = {}

    @AppStorage(AppSettings.Key.selectedTab) private var selectedTabRaw: String = IslandTab.media.rawValue
    @AppStorage(AppSettings.Key.musicControlSlotsV1) private var musicControlSlotsData: Data =
        (try? JSONEncoder().encode(MusicControlButton.defaultLayout)) ?? Data()

    private var selectedTab: IslandTab {
        IslandTab(rawValue: selectedTabRaw) ?? .media
    }

    @State private var tasks: [IslandTask]

    @Namespace private var tabAnimation

    init(
        keyboardMonitor: GlobalKeystrokeMonitor,
        isComposingTask: Binding<Bool>,
        dependencies: AppDependencies = .shared,
        onOpenSettings: @escaping () -> Void = {}
    ) {
        self.keyboardMonitor = keyboardMonitor
        _isComposingTask = isComposingTask
        self.onOpenSettings = onOpenSettings
        self.musicManager = dependencies.musicController as! MusicManager
        self.permissions = dependencies.permissionProvider as! PermissionManager
        self.focusTimer = dependencies.focusTimer as! FocusPandoraTimer
        self.taskRepository = dependencies.taskRepository
        _tasks = State(initialValue: dependencies.taskRepository.load())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            tabBarView

            ZStack(alignment: .top) {
                if selectedTab == .media {
                    IslandNowPlayingView(musicManager: musicManager, musicControlSlots: musicControlSlots)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                } else if selectedTab == .tasks {
                    IslandTasksTabView(tasks: $tasks, isComposingTask: $isComposingTask, taskRepository: taskRepository)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                } else if selectedTab == .focusPandora {
                    IslandFocusTabView(focusTimer: focusTimer)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear {
            if IslandTab(rawValue: selectedTabRaw) == nil {
                // Includes legacy "Settings" value when settings lived in the island.
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
                ForEach(IslandTab.allCases, id: \.self) { tab in
                    tabIconButton(tab)
                }
            }
            .clipShape(Capsule())

            Spacer(minLength: 0)

            settingsGearButton
        }
        .frame(maxWidth: .infinity, minHeight: 26, maxHeight: 26, alignment: .leading)
    }

    private var settingsGearButton: some View {
        Button {
            onOpenSettings()
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 12, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .padding(.horizontal, 13)
                .frame(height: 26)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.white.opacity(0.38))
        .accessibilityLabel("Open Settings")
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
