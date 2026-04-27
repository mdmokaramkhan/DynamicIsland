//
//  IslandSettingsView.swift
//  DynamicIsland
//
//  Settings window with native macOS materials and compact grouped panes.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Main Settings View

struct IslandSettingsView: View {

    // MARK: Dependencies

    @ObservedObject var keyboardMonitor: GlobalKeystrokeMonitor
    @ObservedObject var permissions: PermissionManager
    @ObservedObject private var musicManager = MusicManager.shared

    // MARK: Persisted state

    @AppStorage(AppSettings.Key.musicControlSlotsV1)
    private var musicControlSlotsData: Data =
        (try? JSONEncoder().encode(MusicControlButton.defaultLayout)) ?? Data()

    @AppStorage(AppSettings.Key.focusDefaultMinutes)    private var focusMinutes: Int = 25
    @AppStorage(AppSettings.Key.focusBreakMinutes)      private var breakMinutes: Int = 5
    @AppStorage(AppSettings.Key.focusAutoStartBreak)    private var autoStartBreak: Bool = true
    @AppStorage(AppSettings.Key.focusPauseMedia)        private var pauseMediaOnFocus: Bool = false
    @AppStorage(AppSettings.Key.focusEndSound)          private var endSound: Bool = true
    @AppStorage(AppSettings.Key.focusLongBreakInterval) private var longBreakInterval: Int = 4
    @AppStorage(AppSettings.Key.focusDnd)               private var focusDND: Bool = true
    @AppStorage(AppSettings.Key.focusTintRed)           private var focusTintRed: Double = 1.00
    @AppStorage(AppSettings.Key.focusTintGreen)         private var focusTintGreen: Double = 0.31
    @AppStorage(AppSettings.Key.focusTintBlue)          private var focusTintBlue: Double = 0.12

    @AppStorage("island.display.allDisplays")           private var showOnAllDisplays: Bool = true
    @AppStorage("island.display.autoCollapse")          private var autoCollapse: Bool = true
    @AppStorage("island.display.fadeFullscreen")        private var fadeFullscreen: Bool = false
    @AppStorage("island.display.launchAtLogin")         private var launchAtLogin: Bool = true
    @AppStorage("island.display.defaultMode")           private var defaultMode: Int = 0

    @AppStorage("island.appearance.cornerRadius")       private var cornerRadius: Double = 20
    @AppStorage("island.appearance.widthScale")         private var widthScale: Double = 100
    @AppStorage("island.appearance.vibrancy")           private var vibrancy: Bool = true
    @AppStorage("island.appearance.shadow")             private var dropShadow: Bool = true
    @AppStorage("island.appearance.haptics")            private var haptics: Bool = false
    @AppStorage("island.appearance.position")           private var positionIndex: Int = 0
    @AppStorage("island.appearance.topOffset")          private var topOffset: Double = 4

    @AppStorage("island.shortcuts.captureKeystrokes")   private var captureKeystrokes: Bool = true
    @AppStorage("island.shortcuts.verboseLabels")       private var verboseLabels: Bool = false

    @AppStorage("island.media.scrollTitle")             private var scrollTitle: Bool = true
    @AppStorage("island.media.showArtwork")             private var showArtwork: Bool = true
    @AppStorage("island.media.podcasts")                private var podcastsEnabled: Bool = false

    @AppStorage("island.advanced.debugOverlay")         private var debugOverlay: Bool = false
    @AppStorage("island.advanced.verboseLog")           private var verboseLog: Bool = false
    @AppStorage("island.advanced.animSpeed")            private var animSpeed: Int = 1

    // MARK: Local state

    @StateObject private var viewModel = IslandSettingsViewModel()

    // MARK: Body

    var body: some View {
        ZStack {
            SettingsVisualEffectBackground(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            NavigationSplitView(columnVisibility: $viewModel.splitColumnVisibility) {
                sidebar
            } detail: {
                detailView
            }
            .navigationSplitViewStyle(.balanced)
        }
        .onAppear { permissions.checkAll() }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Dynamic Island")
                    .font(.headline.weight(.semibold))
                Text("Settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)

            VStack(alignment: .leading, spacing: 14) {
                sidebarSection("Island", panes: [.general, .media, .appearance])
                sidebarSection("Workflow", panes: [.focus, .shortcuts])
                sidebarSection("System", panes: [.permissions, .advanced])
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial.opacity(0.55))
        .navigationSplitViewColumnWidth(min: 190, ideal: 205, max: 240)
    }

    private func sidebarSection(_ title: String, panes: [SettingsPane]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 8)

            VStack(spacing: 2) {
                ForEach(panes) { pane in
                    sidebarMenuRow(pane)
                }
            }
        }
    }

    private func sidebarMenuRow(_ pane: SettingsPane) -> some View {
        Button {
            withAnimation(.smooth(duration: 0.16)) {
                        viewModel.selectedPane = pane
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: pane.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(viewModel.selectedPane == pane ? Color.accentColor : Color.secondary)
                    .frame(width: 18)

                Text(pane.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(viewModel.selectedPane == pane ? Color.primary : Color.secondary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(viewModel.selectedPane == pane ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(viewModel.selectedPane == pane ? Color.accentColor.opacity(0.18) : Color.clear, lineWidth: 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail Router

    private var settingsDetailContentMaxWidth: CGFloat {
        640
    }

    private var detailView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                paneHeader

                Group {
                    switch viewModel.selectedPane {
                    case .general:     generalPane
                    case .media:       mediaPane
                    case .appearance:  appearancePane
                    case .focus:       focusPane
                    case .shortcuts:   shortcutsPane
                    case .permissions: permissionsPane
                    case .advanced:    advancedPane
                    }
                }
                .frame(maxWidth: settingsDetailContentMaxWidth, alignment: .leading)
            }
            .frame(maxWidth: settingsDetailContentMaxWidth, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 26)
            .padding(.bottom, 30)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }

    private var paneHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(
                        colors: viewModel.selectedPane.iconColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 34, height: 34)
                Image(systemName: viewModel.selectedPane.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.selectedPane.title)
                    .font(.title2.weight(.semibold))
                Text(viewModel.selectedPane.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: settingsDetailContentMaxWidth, alignment: .leading)
    }

    // MARK: - General Pane

    private var generalPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Display")
            settingsCard {
                settingsRow(
                    symbol: "rectangle.on.rectangle",
                    label: "Show on all displays",
                    description: "Mirror the island across monitors"
                ) { Toggle("", isOn: $showOnAllDisplays).labelsHidden().toggleStyle(.switch) }

                settingsRow(
                    symbol: "arrow.down.right.and.arrow.up.left",
                    label: "Auto-collapse when idle",
                    description: "Shrink after 4 s of no activity"
                ) { Toggle("", isOn: $autoCollapse).labelsHidden().toggleStyle(.switch) }

                settingsRow(
                    symbol: "rectangle.slash",
                    label: "Fade on fullscreen",
                    description: "Hide automatically in fullscreen apps"
                ) { Toggle("", isOn: $fadeFullscreen).labelsHidden().toggleStyle(.switch) }

                settingsRow(
                    symbol: "arrow.up.right.square",
                    label: "Launch at login",
                    description: "Start when macOS boots"
                ) { Toggle("", isOn: $launchAtLogin).labelsHidden().toggleStyle(.switch) }
            }

            sectionLabel("Default mode")
                .padding(.top, 18)
            settingsCard {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 10)], spacing: 10) {
                    radioItem(title: "Keystroke", icon: "keyboard", tag: 0)
                    radioItem(title: "Media", icon: "music.note", tag: 1)
                    radioItem(title: "Clock", icon: "clock", tag: 2)
                    radioItem(title: "Minimal", icon: "circle", tag: 3)
                }
                .padding(10)
            }

            versionRow
                .padding(.top, 12)
        }
    }

    // MARK: - Picker Item
    private func radioItem(title: String, icon: String, tag: Int) -> some View {
        VStack(spacing: 6) {

            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))

            Text(title)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)

        }
        .foregroundStyle(defaultMode == tag ? Color.accentColor : Color.primary)
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(defaultMode == tag
                      ? Color.accentColor.opacity(0.18)
                      : Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    defaultMode == tag
                    ? Color.accentColor.opacity(0.65)
                    : Color.primary.opacity(0.08),
                    lineWidth: defaultMode == tag ? 1.2 : 0.5
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                defaultMode = tag
            }
        }
    }

    // MARK: - Media Pane

    private var mediaPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Button layout")
            settingsCard {
                musicSlotConfigurationSection
            }

            sectionLabel("Sources")
                .padding(.top, 18)
            settingsCard {
                settingsRow(
                    symbol: "music.note",
                    symbolColor: Color(red:1,green:0.22,blue:0.37),
                    label: "Apple Music",
                    description: "Native AppleScript integration"
                ) { StatusBadge(.granted) }

                settingsRow(
                    symbol: "dot.radiowaves.right",
                    symbolColor: Color(red:0.11,green:0.84,blue:0.37),
                    label: "Spotify",
                    description: "AppleScript automation"
                ) {
                    HStack(spacing: 6) {
                        StatusBadge(permissions.spotifyAutomation)
                        if permissions.spotifyAutomation != .granted {
                            Button("Allow") { Task { await permissions.requestSpotifyAutomation() } }
                                .controlSize(.small)
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }

                settingsRow(
                    symbol: "mic.fill",
                    symbolColor: Color(red:1,green:0.62,blue:0.04),
                    label: "Podcast apps",
                    description: "Overcast, Pocket Casts & others"
                ) { Toggle("", isOn: $podcastsEnabled).labelsHidden().toggleStyle(.switch) }
            }

            sectionLabel("Display")
                .padding(.top, 18)
            settingsCard {
                settingsRow(
                    symbol: "ellipsis.rectangle",
                    label: "Scroll long track names",
                    description: "Marquee text when it overflows"
                ) { Toggle("", isOn: $scrollTitle).labelsHidden().toggleStyle(.switch) }

                settingsRow(
                    symbol: "photo.fill",
                    label: "Show album artwork",
                    description: "Thumbnail next to track info"
                ) { Toggle("", isOn: $showArtwork).labelsHidden().toggleStyle(.switch) }
            }
        }
    }

    // MARK: - Appearance Pane

    private var appearancePane: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Shape")
            settingsCard {
                VStack(alignment: .leading, spacing: 14) {
                    sliderRow(
                        label: "Corner radius",
                        value: $cornerRadius,
                        range: 8...32, step: 1,
                        unit: "px",
                        ticks: ["8", "20", "32"]
                    )
                    Divider().opacity(0.5)
                    sliderRow(
                        label: "Width expansion",
                        value: $widthScale,
                        range: 80...160, step: 1,
                        unit: "%",
                        ticks: ["80%", "100%", "160%"]
                    )
                }
                .padding(14)
            }

            sectionLabel("Visual effects")
                .padding(.top, 18)
            settingsCard {
                settingsRow(
                    symbol: "water.waves",
                    symbolColor: Color(red:0.00,green:0.48,blue:1.00),
                    label: "Frosted glass vibrancy",
                    description: "Blur and tint the background"
                ) { Toggle("", isOn: $vibrancy).labelsHidden().toggleStyle(.switch) }

                settingsRow(
                    symbol: "shadow",
                    symbolColor: Color(red:0.00,green:0.48,blue:1.00),
                    label: "Drop shadow",
                    description: "Soft ambient shadow below island"
                ) { Toggle("", isOn: $dropShadow).labelsHidden().toggleStyle(.switch) }

                settingsRow(
                    symbol: "hand.tap.fill",
                    symbolColor: Color(red:0.75,green:0.35,blue:0.95),
                    label: "Haptic feedback",
                    description: "Vibration on tap (MacBook trackpad)"
                ) { Toggle("", isOn: $haptics).labelsHidden().toggleStyle(.switch) }
            }

            sectionLabel("Position")
                .padding(.top, 18)
            settingsCard {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Horizontal alignment")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("", selection: $positionIndex) {
                            Text("Leading").tag(0)
                            Text("Center").tag(1)
                            Text("Trailing").tag(2)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding([.horizontal, .top], 14)

                    Divider().opacity(0.5).padding(.horizontal, 14)

                    sliderRow(
                        label: "Top offset from menu bar",
                        value: $topOffset,
                        range: 0...20, step: 1,
                        unit: "px",
                        ticks: ["0", "10", "20"]
                    )
                    .padding([.horizontal, .bottom], 14)
                }
                .padding(0)
            }
        }
    }

    // MARK: - Focus Pane

    private var focusPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Session length")
            settingsCard {
                VStack(alignment: .leading, spacing: 14) {
                    sliderRow(
                        label: "Focus duration",
                        value: Binding(
                            get: { Double(focusMinutes) },
                            set: { focusMinutes = Int(($0 / 5).rounded() * 5) }
                        ),
                        range: 5...90, step: 5,
                        unit: "min",
                        ticks: ["5", "30", "60", "90"]
                    )
                    Divider().opacity(0.5)
                    sliderRow(
                        label: "Break duration",
                        value: Binding(
                            get: { Double(breakMinutes) },
                            set: { breakMinutes = Int($0) }
                        ),
                        range: 1...30, step: 1,
                        unit: "min",
                        ticks: ["1", "15", "30"]
                    )
                }
                .padding(14)
            }

            sectionLabel("Behaviour")
                .padding(.top, 18)
            settingsCard {
                settingsRow(
                    symbol: "arrow.clockwise",
                    symbolColor: Color(red:0.19,green:0.82,blue:0.35),
                    label: "Auto-start break timer",
                    description: "Begin break when session ends"
                ) { Toggle("", isOn: $autoStartBreak).labelsHidden().toggleStyle(.switch) }

                settingsRow(
                    symbol: "pause.circle.fill",
                    symbolColor: Color(red:1,green:0.62,blue:0.04),
                    label: "Pause media during focus",
                    description: "Auto-pause music when you start"
                ) { Toggle("", isOn: $pauseMediaOnFocus).labelsHidden().toggleStyle(.switch) }

                settingsRow(
                    symbol: "bell.fill",
                    symbolColor: Color(red:0.00,green:0.48,blue:1.00),
                    label: "End-of-session sound",
                    description: "Play a soft chime at completion"
                ) { Toggle("", isOn: $endSound).labelsHidden().toggleStyle(.switch) }

                settingsRow(
                    symbol: "moon.fill",
                    symbolColor: Color(red:0.75,green:0.35,blue:0.95),
                    label: "Do Not Disturb during focus",
                    description: "Enable system DND for the session"
                ) { Toggle("", isOn: $focusDND).labelsHidden().toggleStyle(.switch) }

                settingsRow(
                    symbol: "list.number",
                    label: "Long break interval",
                    description: "Extended break every N sessions"
                ) {
                    Picker("", selection: $longBreakInterval) {
                        Text("3").tag(3)
                        Text("4").tag(4)
                        Text("5").tag(5)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
            }

            sectionLabel("Color")
                .padding(.top, 18)
            settingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        ForEach(focusTintPresets, id: \.name) { preset in
                            focusTintPresetButton(preset)
                        }

                        Spacer(minLength: 0)

                        ColorPicker("", selection: focusTintBinding, supportsOpacity: false)
                            .labelsHidden()
                            .controlSize(.small)
                    }

                    Text("Sets the Pandora glow, progress ring, and running-state tint.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
            }
        }
    }

    private var focusTintBinding: Binding<Color> {
        Binding(
            get: {
                Color(red: focusTintRed, green: focusTintGreen, blue: focusTintBlue)
            },
            set: { newValue in
                if let components = NSColor(newValue).usingColorSpace(.deviceRGB) {
                    focusTintRed = components.redComponent
                    focusTintGreen = components.greenComponent
                    focusTintBlue = components.blueComponent
                }
            }
        )
    }

    private var focusTintPresets: [(name: String, color: Color, red: Double, green: Double, blue: Double)] {
        [
            ("Ember", Color(red: 1.00, green: 0.31, blue: 0.12), 1.00, 0.31, 0.12),
            ("Mango", Color(red: 1.00, green: 0.58, blue: 0.16), 1.00, 0.58, 0.16),
            ("Rose", Color(red: 1.00, green: 0.28, blue: 0.42), 1.00, 0.28, 0.42),
            ("Mint", Color(red: 0.32, green: 0.92, blue: 0.62), 0.32, 0.92, 0.62),
            ("Sky", Color(red: 0.36, green: 0.70, blue: 1.00), 0.36, 0.70, 1.00)
        ]
    }

    private func focusTintPresetButton(_ preset: (name: String, color: Color, red: Double, green: Double, blue: Double)) -> some View {
        Button {
            withAnimation(.smooth(duration: 0.16)) {
                focusTintRed = preset.red
                focusTintGreen = preset.green
                focusTintBlue = preset.blue
            }
        } label: {
            Circle()
                .fill(preset.color)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .strokeBorder(Color.primary.opacity(focusTintMatches(preset) ? 0.55 : 0.12), lineWidth: focusTintMatches(preset) ? 2 : 1)
                )
                .shadow(color: preset.color.opacity(0.25), radius: 4, y: 1)
        }
        .buttonStyle(.plain)
        .help(preset.name)
    }

    private func focusTintMatches(_ preset: (name: String, color: Color, red: Double, green: Double, blue: Double)) -> Bool {
        abs(focusTintRed - preset.red) < 0.01 &&
        abs(focusTintGreen - preset.green) < 0.01 &&
        abs(focusTintBlue - preset.blue) < 0.01
    }

    // MARK: - Shortcuts Pane

    private var shortcutsPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Global hotkeys")
            settingsCard {
                shortcutRow(label: "Toggle island visibility",  keys: ["⌘", "⌥", "D"])
                shortcutRow(label: "Start focus session",       keys: ["⌘", "⌥", "F"])
                shortcutRow(label: "Play / pause media",        keys: ["⌘", "⌥", "Space"])
                shortcutRow(label: "Skip to next track",        keys: ["⌘", "⌥", "→"])
                shortcutRow(label: "Previous track",            keys: ["⌘", "⌥", "←"])
                shortcutRow(label: "Expand island",             keys: ["⌘", "⌥", "E"])
            }

            sectionLabel("Keystroke capture")
                .padding(.top, 18)
            settingsCard {
                settingsRow(
                    symbol: "keyboard",
                    symbolColor: Color(red:0.00,green:0.48,blue:1.00),
                    label: "Capture keystrokes",
                    description: "Show modifier+key combos in the island"
                ) { Toggle("", isOn: $captureKeystrokes).labelsHidden().toggleStyle(.switch) }

                settingsRow(
                    symbol: "character.cursor.ibeam",
                    label: "Verbose key labels",
                    description: "Full names instead of symbols (e.g. Option vs ⌥)"
                ) { Toggle("", isOn: $verboseLabels).labelsHidden().toggleStyle(.switch) }
            }
        }
    }

    // MARK: - Permissions Pane

    private var permissionsPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Status")
            settingsCard {
                settingsInfoRow(
                    symbol: "keyboard.fill",
                    symbolColor: statusAccent,
                    label: "Key capture",
                    value: keyboardMonitor.statusLine
                )
            }

            sectionLabel("System access")
                .padding(.top, 18)
            settingsCard {
                permissionRow(
                    symbol: "figure.wave",
                    label: "Accessibility",
                    description: "Required for global keystroke capture",
                    status: permissions.accessibility
                ) {
                    permissions.requestAccessibility()
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        permissions.checkAccessibility()
                    }
                }

                permissionRow(
                    symbol: "music.note",
                    label: "Apple Music automation",
                    description: "Read and control now-playing state",
                    status: permissions.appleMusicAutomation
                ) {
                    Task { await permissions.requestAppleMusicAutomation() }
                }

                permissionRow(
                    symbol: "dot.radiowaves.right",
                    label: "Spotify automation",
                    description: "Read and control Spotify playback",
                    status: permissions.spotifyAutomation
                ) {
                    Task { await permissions.requestSpotifyAutomation() }
                }

                permissionRow(
                    symbol: "bell.badge",
                    label: "Notifications",
                    description: "Focus session alerts and reminders",
                    status: .notDetermined
                ) {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
                }
            }

            sectionLabel("Diagnostics")
                .padding(.top, 18)
            settingsCard {
                diagnosticRow(label: "Key capture status", value: "Active")
                diagnosticRow(label: "Event tap", value: "Running")
                diagnosticRow(label: "AppleScript bridge", value: "Ready")
                diagnosticRow(label: "Build", value: appVersionLabel)
            }
        }
    }

    // MARK: - Advanced Pane

    private var advancedPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Developer")
            settingsCard {
                settingsRow(
                    symbol: "rectangle.dashed",
                    label: "Debug overlay",
                    description: "Frame rate and event log in island"
                ) { Toggle("", isOn: $debugOverlay).labelsHidden().toggleStyle(.switch) }

                settingsRow(
                    symbol: "doc.text.magnifyingglass",
                    label: "Verbose logging",
                    description: "Write detailed logs to Console.app"
                ) { Toggle("", isOn: $verboseLog).labelsHidden().toggleStyle(.switch) }

                settingsRow(
                    symbol: "hare.fill",
                    label: "Animation speed",
                    description: "How fast island transitions play"
                ) {
                    Picker("", selection: $animSpeed) {
                        Text("Slow").tag(0)
                        Text("Normal").tag(1)
                        Text("Fast").tag(2)
                        Text("Off").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
            }

            sectionLabel("Data")
                .padding(.top, 18)
            settingsCard {
                diagnosticRow(label: "Preferences", value: "UserDefaults · app group")
                diagnosticRow(label: "Config path", value: "~/Library/Preferences/…")

                HStack(spacing: 8) {
                    Spacer()
                    Button("Export config") {}
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Button("Reset all settings") {}
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundStyle(.red)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
    }

    // MARK: - Music Slot Configuration

    private var musicSlotConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Action buttons in the now playing row")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text("Drag or tap to customise")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)

            HStack(alignment: .top, spacing: 10) {
                HStack(spacing: 5) {
                    ForEach(0..<5, id: \.self) { index in
                        musicSlotPreview(musicControlSlots[index])
                            .onDrag { NSItemProvider(object: NSString(string: "slot:\(index)")) }
                            .onDrop(of: [UTType.plainText], isTargeted: nil) { providers in
                                handleMusicSlotDrop(providers, toIndex: index)
                            }
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5)
                        )
                )

                VStack(spacing: 4) {
                    musicSlotTrash
                    Button("Reset") {
                        withAnimation(.smooth(duration: 0.18)) {
                            saveMusicControlSlots(MusicControlButton.defaultLayout)
                        }
                    }
                    .buttonStyle(.borderless)
                    .font(.caption.weight(.semibold))
                }
            }
            .padding(.horizontal, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MusicControlButton.pickerOptions) { control in
                        VStack(spacing: 4) {
                            musicSlotPreview(control)
                                .onDrag { NSItemProvider(object: NSString(string: "control:\(control.rawValue)")) }
                                .onTapGesture { addMusicControlToFirstOpenSlot(control) }
                            Text(control.label)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(width: 52)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 14)
            }
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private func musicSlotPreview(_ slot: MusicControlButton) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThinMaterial)
                .frame(width: 36, height: 36)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
            if slot == .none {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.tertiary)
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: musicSlotIcon(for: slot))
                    .font(.system(size: slot.prefersLargeScale ? 16 : 13, weight: .medium))
                    .foregroundStyle(musicSlotPreviewColor(for: slot))
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var musicSlotTrash: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThinMaterial)
                .frame(width: 36, height: 36)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
            Image(systemName: "trash")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onDrop(of: [UTType.plainText], isTargeted: nil) { providers in
            handleMusicSlotTrashDrop(providers)
        }
    }

    private func musicSlotIcon(for slot: MusicControlButton) -> String {
        if slot == .playPause { return musicManager.isPlaying ? "pause.fill" : "play.fill" }
        if slot == .repeatMode, musicManager.repeatMode == .one { return "repeat.1" }
        if slot == .favorite, musicManager.isFavoriteTrack { return "heart.fill" }
        return slot.iconName
    }

    private func musicSlotPreviewColor(for slot: MusicControlButton) -> Color {
        let dim = Color.primary.opacity(0.70)
        switch slot {
        case .shuffle:    return musicManager.isShuffled ? .red : dim
        case .repeatMode: return musicManager.repeatMode != .off ? .red : dim
        case .favorite:   return musicManager.isFavoriteTrack ? .red : dim
        default:          return dim
        }
    }

    private var musicControlSlots: [MusicControlButton] {
        let decoded = (try? JSONDecoder().decode([MusicControlButton].self, from: musicControlSlotsData))
            ?? MusicControlButton.defaultLayout
        return normalizedSlots(decoded)
    }

    private func normalizedSlots(_ slots: [MusicControlButton]) -> [MusicControlButton] {
        let n = 5
        if slots.count == n { return slots }
        if slots.count > n { return Array(slots.prefix(n)) }
        return slots + Array(repeating: .none, count: n - slots.count)
    }

    private func saveMusicControlSlots(_ slots: [MusicControlButton]) {
        if let data = try? JSONEncoder().encode(normalizedSlots(slots)) {
            musicControlSlotsData = data
        }
    }

    private func addMusicControlToFirstOpenSlot(_ control: MusicControlButton) {
        var slots = musicControlSlots
        if let existing = slots.firstIndex(of: control) { slots[existing] = .none }
        let target = slots.firstIndex(of: .none) ?? 0
        slots[target] = control
        withAnimation(.smooth(duration: 0.18)) { saveMusicControlSlots(slots) }
    }

    private func handleMusicSlotDrop(_ providers: [NSItemProvider], toIndex: Int) -> Bool {
        loadDropString(from: providers) { raw in processMusicSlotDrop(raw, toIndex: toIndex) }
    }

    private func handleMusicSlotTrashDrop(_ providers: [NSItemProvider]) -> Bool {
        loadDropString(from: providers) { raw in
            guard raw.hasPrefix("slot:"),
                  let from = Int(raw.replacingOccurrences(of: "slot:", with: "")),
                  (0..<5).contains(from) else { return }
            var slots = musicControlSlots
            slots[from] = .none
            withAnimation(.smooth(duration: 0.18)) { saveMusicControlSlots(slots) }
        }
    }

    private func loadDropString(from providers: [NSItemProvider], onLoad: @escaping (String) -> Void) -> Bool {
        for provider in providers where provider.canLoadObject(ofClass: NSString.self) {
            provider.loadObject(ofClass: NSString.self) { item, _ in
                guard let s = item as? NSString else { return }
                DispatchQueue.main.async { onLoad(s as String) }
            }
            return true
        }
        return false
    }

    private func processMusicSlotDrop(_ raw: String, toIndex: Int) {
        var slots = musicControlSlots
        if raw.hasPrefix("slot:") {
            let from = Int(raw.replacingOccurrences(of: "slot:", with: "")) ?? -1
            guard (0..<5).contains(from), (0..<5).contains(toIndex) else { return }
            slots.swapAt(from, toIndex)
        } else if raw.hasPrefix("control:") {
            let value = raw.replacingOccurrences(of: "control:", with: "")
            guard let control = MusicControlButton(rawValue: value) else { return }
            if let existing = slots.firstIndex(of: control), existing != toIndex { slots[existing] = .none }
            slots[toIndex] = control
        }
        withAnimation(.smooth(duration: 0.18)) { saveMusicControlSlots(slots) }
    }

    // MARK: - Reusable Components

    // Native grouped settings wrapper
    @ViewBuilder
    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
        )
    }

    // Generic settings row with trailing accessory
    @ViewBuilder
    private func settingsRow<Accessory: View>(
        symbol: String,
        symbolColor: Color = Color.secondary,
        label: String,
        description: String? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(symbolColor.opacity(0.12))
                    .frame(width: 26, height: 26)
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(symbolColor)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                if let d = description {
                    Text(d)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)
            accessory()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.5).padding(.leading, 50)
        }
    }

    // Info-only row (no toggle)
    private func settingsInfoRow(symbol: String, symbolColor: Color, label: String, value: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(symbolColor.opacity(0.12))
                    .frame(width: 26, height: 26)
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(symbolColor)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.subheadline).foregroundStyle(.primary)
                Text(value).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    // Permission row
    private func permissionRow(
        symbol: String,
        label: String,
        description: String,
        status: PermissionStatus,
        onAllow: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(permissionAccent(status).opacity(0.12))
                    .frame(width: 26, height: 26)
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(permissionAccent(status))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.subheadline).foregroundStyle(.primary)
                Text(description).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 8)
            StatusBadge(status)
            if status != .granted {
                Button("Allow", action: onAllow)
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.5).padding(.leading, 50)
        }
        .animation(.smooth(duration: 0.2), value: status)
    }

    // Shortcut row
    private func shortcutRow(label: String, keys: [String]) -> some View {
        HStack(alignment: .center) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer(minLength: 12)
            HStack(spacing: 3) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                                )
                        )
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.5).padding(.leading, 14)
        }
    }

    // Diagnostic key-value row
    private func diagnosticRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.5).padding(.leading, 14)
        }
    }

    // Slider row
    private func sliderRow(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        unit: String,
        ticks: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(Int(value.wrappedValue))")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Slider(value: value, in: range, step: step)

            HStack {
                ForEach(ticks, id: \.self) { t in
                    Text(t).font(.caption2).foregroundStyle(.tertiary)
                    if t != ticks.last { Spacer() }
                }
            }
        }
    }

    // Section heading
    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 2)
            .padding(.bottom, 7)
            .padding(.leading, 2)
    }

    // Version row
    private var versionRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "app.badge.checkmark.fill")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(appVersionLabel)
                .font(.caption.weight(.medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.leading, 2)
    }

    // MARK: - Helpers

    private var appVersionLabel: String {
        let s = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return s.map { "v\($0)" } ?? "v—"
    }

    private var statusAccent: Color {
        switch keyboardMonitor.authorization {
        case .authorized:           return .mint
        case .missingAccessibility: return .orange
        }
    }

    private func permissionAccent(_ status: PermissionStatus) -> Color {
        switch status {
        case .granted:       return .mint
        case .denied:        return Color(red:1, green:0.23, blue:0.19)
        case .notDetermined: return .orange
        case .unknown:       return .secondary
        }
    }
}

// MARK: - Status Badge

private struct StatusBadge: View {
    let status: PermissionStatus
    init(_ status: PermissionStatus) { self.status = status }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(status.label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.10))
        .clipShape(Capsule())
    }

    private var color: Color {
        switch status {
        case .granted:       return .mint
        case .denied:        return Color(red:1, green:0.23, blue:0.19)
        case .notDetermined: return .orange
        case .unknown:       return .secondary
        }
    }
}

// MARK: - Preview

#Preview("Settings") {
    IslandSettingsView(
        keyboardMonitor: GlobalKeystrokeMonitor(),
        permissions: PermissionManager.shared
    )
    .frame(minWidth: 760, minHeight: 560)
}
