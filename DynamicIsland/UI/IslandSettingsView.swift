//
//  IslandSettingsView.swift
//  DynamicIsland
//

import SwiftUI
import UniformTypeIdentifiers

struct IslandSettingsView: View {
    @ObservedObject var keyboardMonitor: GlobalKeystrokeMonitor
    @ObservedObject var permissions: PermissionManager
    @ObservedObject var musicManager: MusicManager
    @Binding var musicControlSlotsData: Data
    let focusPandoraMinutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.8))
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Settings")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.94))
                    Text("Quick controls for the island")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(IslandChrome.subtext)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text(appVersionLabel)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.055)))
            }

            musicSlotConfigurationSection

            VStack(spacing: 6) {
                settingsInfoRow(
                    icon: "keyboard",
                    title: "Key capture",
                    value: keyboardMonitor.statusLine,
                    accent: welcomeStatusColor
                )

                settingsPermissionRow(
                    icon: "hand.raised",
                    title: "Accessibility",
                    description: "Needed to show keystrokes in the island",
                    status: permissions.accessibility
                ) {
                    permissions.requestAccessibility()
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        permissions.checkAccessibility()
                    }
                }

                settingsPermissionRow(
                    icon: "music.note",
                    title: "Apple Music",
                    description: "Controls now-playing in Apple Music",
                    status: permissions.appleMusicAutomation
                ) {
                    Task { await permissions.requestAppleMusicAutomation() }
                }

                settingsPermissionRow(
                    icon: "headphones",
                    title: "Spotify",
                    description: "Controls now-playing in Spotify",
                    status: permissions.spotifyAutomation
                ) {
                    Task { await permissions.requestSpotifyAutomation() }
                }

                settingsInfoRow(
                    icon: "timer",
                    title: "Default focus",
                    value: "\(focusPandoraMinutes) minutes",
                    accent: Color.white.opacity(0.55)
                )
            }
            .onAppear { permissions.checkAll() }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(IslandPanelBackground.notchPanel(cornerRadius: 15))
    }

    private var appVersionLabel: String {
        let s = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return s.map { "v\($0)" } ?? "v—"
    }

    private var welcomeStatusColor: Color {
        switch keyboardMonitor.authorization {
        case .authorized:
            return Color.mint
        case .missingAccessibility:
            return Color.orange
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

    private func saveMusicControlSlots(_ slots: [MusicControlButton]) {
        let normalized = normalizedMusicControlSlots(slots)
        if let data = try? JSONEncoder().encode(normalized) {
            musicControlSlotsData = data
        }
    }

    // MARK: - Music slot configuration

    private var musicSlotConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Music Controls")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.72))
                Spacer(minLength: 0)
                Text("Drag or tap to customize")
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(IslandChrome.subtext)
            }

            HStack(alignment: .top, spacing: 10) {
                HStack(spacing: 6) {
                    ForEach(0 ..< 5, id: \.self) { index in
                        let slot = musicControlSlots[index]
                        musicSlotPreview(slot)
                            .onDrag {
                                NSItemProvider(object: NSString(string: "slot:\(index)"))
                            }
                            .onDrop(of: [UTType.plainText], isTargeted: nil) { providers in
                                handleMusicSlotDrop(providers, toIndex: index)
                            }
                    }
                }
                .padding(9)
                .background(IslandPanelBackground.notchSubpanel(cornerRadius: 11))

                VStack(spacing: 5) {
                    musicSlotTrash
                    Button("Reset") {
                        withAnimation(.smooth(duration: 0.18)) {
                            saveMusicControlSlots(MusicControlButton.defaultLayout)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.5))
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MusicControlButton.pickerOptions) { control in
                        VStack(spacing: 4) {
                            musicSlotPreview(control)
                                .onDrag {
                                    NSItemProvider(object: NSString(string: "control:\(control.rawValue)"))
                                }
                                .onTapGesture {
                                    addMusicControlToFirstOpenSlot(control)
                                }
                            Text(control.label)
                                .font(.system(size: 7, weight: .semibold, design: .rounded))
                                .foregroundStyle(IslandChrome.subtext)
                                .frame(width: 54)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(11)
        .background(IslandPanelBackground.notchSubpanel(cornerRadius: 12))
    }

    private var musicSlotTrash: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .frame(width: 38, height: 38)
            Image(systemName: "trash")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.56))
        }
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .onDrop(of: [UTType.plainText], isTargeted: nil) { providers in
            handleMusicSlotTrashDrop(providers)
        }
    }

    @ViewBuilder
    private func musicSlotPreview(_ slot: MusicControlButton) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .frame(width: 38, height: 38)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            if slot == .none {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color.white.opacity(0.22))
                    .frame(width: 26, height: 26)
            } else {
                Image(systemName: musicSlotIcon(for: slot))
                    .font(.system(size: slot.prefersLargeScale ? 17 : 14, weight: .medium))
                    .foregroundStyle(musicSlotPreviewColor(for: slot))
                    .frame(width: 26, height: 26)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func musicSlotIcon(for slot: MusicControlButton) -> String {
        if slot == .playPause {
            return musicManager.isPlaying ? "pause.fill" : "play.fill"
        }
        if slot == .repeatMode, musicManager.repeatMode == .one {
            return "repeat.1"
        }
        if slot == .favorite, musicManager.isFavoriteTrack {
            return "heart.fill"
        }
        return slot.iconName
    }

    private func musicSlotPreviewColor(for slot: MusicControlButton) -> Color {
        switch slot {
        case .shuffle:
            return musicManager.isShuffled ? .red : Color.white.opacity(0.8)
        case .repeatMode:
            return musicManager.repeatMode != .off ? .red : Color.white.opacity(0.8)
        case .favorite:
            return musicManager.isFavoriteTrack ? .red : Color.white.opacity(0.8)
        default:
            return Color.white.opacity(0.8)
        }
    }

    private func addMusicControlToFirstOpenSlot(_ control: MusicControlButton) {
        var slots = musicControlSlots
        if let existing = slots.firstIndex(of: control) {
            slots[existing] = .none
        }
        let target = slots.firstIndex(of: .none) ?? 0
        slots[target] = control
        withAnimation(.smooth(duration: 0.18)) {
            saveMusicControlSlots(slots)
        }
    }

    private func handleMusicSlotDrop(_ providers: [NSItemProvider], toIndex: Int) -> Bool {
        loadMusicSlotDropString(from: providers) { raw in
            processMusicSlotDrop(raw, toIndex: toIndex)
        }
    }

    private func handleMusicSlotTrashDrop(_ providers: [NSItemProvider]) -> Bool {
        loadMusicSlotDropString(from: providers) { raw in
            guard raw.hasPrefix("slot:") else { return }
            let from = Int(raw.replacingOccurrences(of: "slot:", with: "")) ?? -1
            guard (0 ..< 5).contains(from) else { return }
            var slots = musicControlSlots
            slots[from] = .none
            withAnimation(.smooth(duration: 0.18)) {
                saveMusicControlSlots(slots)
            }
        }
    }

    private func loadMusicSlotDropString(
        from providers: [NSItemProvider],
        onLoad: @escaping (String) -> Void
    ) -> Bool {
        for provider in providers where provider.canLoadObject(ofClass: NSString.self) {
            provider.loadObject(ofClass: NSString.self) { item, _ in
                guard let string = item as? NSString else { return }
                DispatchQueue.main.async {
                    onLoad(string as String)
                }
            }
            return true
        }
        return false
    }

    private func processMusicSlotDrop(_ raw: String, toIndex: Int) {
        var slots = musicControlSlots
        if raw.hasPrefix("slot:") {
            let from = Int(raw.replacingOccurrences(of: "slot:", with: "")) ?? -1
            guard (0 ..< 5).contains(from), (0 ..< 5).contains(toIndex) else { return }
            slots.swapAt(from, toIndex)
        } else if raw.hasPrefix("control:") {
            let value = raw.replacingOccurrences(of: "control:", with: "")
            guard let control = MusicControlButton(rawValue: value) else { return }
            if let existing = slots.firstIndex(of: control), existing != toIndex {
                slots[existing] = .none
            }
            slots[toIndex] = control
        }
        withAnimation(.smooth(duration: 0.18)) {
            saveMusicControlSlots(slots)
        }
    }

    // MARK: - Settings rows

    private func settingsPermissionRow(
        icon: String,
        title: String,
        description: String,
        status: PermissionStatus,
        onAllow: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(settingsPermissionAccent(status).opacity(0.12))
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(settingsPermissionAccent(status).opacity(0.92))
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.82))
                Text(description)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(IslandChrome.subtext)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            HStack(spacing: 3) {
                Circle()
                    .fill(settingsPermissionAccent(status))
                    .frame(width: 5, height: 5)
                    .shadow(color: settingsPermissionAccent(status).opacity(0.55), radius: 2)
                Text(status.label)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(settingsPermissionAccent(status))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(settingsPermissionAccent(status).opacity(0.1)))

            if status != .granted {
                Button {
                    onAllow()
                } label: {
                    Text("Allow")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.orange.opacity(0.9))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.1))
                                .overlay(Capsule().stroke(Color.orange.opacity(0.22), lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(status == .granted ? 0.03 : 0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            status == .granted
                                ? Color.mint.opacity(0.18)
                                : Color.white.opacity(0.07),
                            lineWidth: 1
                        )
                )
        )
        .animation(.smooth(duration: 0.2), value: status)
    }

    private func settingsPermissionAccent(_ status: PermissionStatus) -> Color {
        switch status {
        case .granted: return .mint
        case .denied: return Color(red: 1, green: 0.27, blue: 0.27)
        case .notDetermined: return .orange
        case .unknown: return Color.white.opacity(0.5)
        }
    }

    private func settingsInfoRow(
        icon: String,
        title: String,
        value: String,
        accent: Color,
        showsArrow: Bool = false
    ) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.12))
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accent.opacity(0.92))
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.82))
                Text(value)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(IslandChrome.subtext)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if showsArrow {
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.36))
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(IslandPanelBackground.notchSubpanel(cornerRadius: 12))
    }
}

#Preview("Settings") {
    @Previewable @State var slotsData: Data =
        (try? JSONEncoder().encode(MusicControlButton.defaultLayout)) ?? Data()
    IslandSettingsView(
        keyboardMonitor: GlobalKeystrokeMonitor(),
        permissions: PermissionManager.shared,
        musicManager: MusicManager.shared,
        musicControlSlotsData: $slotsData,
        focusPandoraMinutes: 25
    )
    .frame(width: 440, alignment: .leading)
    .padding(16)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
