//
//  IslandTabView.swift
//  DynamicIsland
//

import SwiftUI
import Combine

// MARK: - Task model

struct IslandTask: Identifiable, Codable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
}

// MARK: - Task persistence

private enum TaskStorage {
    static let key = "island.tasks.v1"

    static func load() -> [IslandTask] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let tasks = try? JSONDecoder().decode([IslandTask].self, from: data)
        else { return [] }
        return tasks
    }

    static func save(_ tasks: [IslandTask]) {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

// MARK: - Tabs

enum IslandTab: String, CaseIterable {
    case welcome = "Welcome"
    case tasks = "Tasks"
    case focusPandora = "Focus"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .welcome:     return "sparkles"
        case .tasks:       return "checkmark.circle"
        case .focusPandora: return "hourglass"
        case .settings:    return "gearshape"
        }
    }
}

// MARK: - Styling (shared with welcome + tasks)

private enum IslandChrome {
    static let cardFill = Color.white.opacity(0.06)
    static let cardStroke = Color.white.opacity(0.12)
    static let subtext = Color.white.opacity(0.48)
    static let linkAccent = Color(red: 0.45, green: 0.78, blue: 0.95)
    static let heroRing = Color.white.opacity(0.14)
    static let featureWell = Color.white.opacity(0.045)
}

/// Neutral, minimal styling for the Focus (Pandora) timer — no accent color noise.
private enum PandoraChrome {
    static let primary = Color.white.opacity(0.9)
    static let dim = Color.white.opacity(0.28)
    static let muted = Color.white.opacity(0.42)
    static let panel = Color.white.opacity(0.04)
    static let panelStroke = Color.white.opacity(0.09)
    static let divider = Color.white.opacity(0.12)
}

// MARK: - Main view

struct IslandTabView: View {
    @ObservedObject var keyboardMonitor: GlobalKeystrokeMonitor
    @Binding var isComposingTask: Bool

    /// Persists across island collapse/expand and app restarts.
    @AppStorage("island.selectedTab") private var selectedTabRaw: String = IslandTab.welcome.rawValue

    private var selectedTab: IslandTab {
        IslandTab(rawValue: selectedTabRaw) ?? .welcome
    }
    @State private var tasks: [IslandTask] = TaskStorage.load()
    @State private var newTaskTitle = ""
    @FocusState private var isInputFocused: Bool

    // Focus Pandora — focus session timer
    @State private var focusPandoraMinutes: Int = 25
    @State private var focusPandoraRemainingSec: Int = 25 * 60
    @State private var focusPandoraIsRunning: Bool = false
    @State private var focusPandoraPulse: Bool = false

    // Namespace for the sliding capsule matchedGeometryEffect (boringNotch style)
    @Namespace private var tabAnimation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Icon-only tab bar — top-left, sliding capsule indicator
            tabBarView

            // Tab content — each view has its own transition so SwiftUI can
            // interpolate the island height as it animates between them.
            ZStack(alignment: .top) {
                if selectedTab == .welcome {
                    welcomeView
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                } else if selectedTab == .tasks {
                    tasksView
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                } else if selectedTab == .focusPandora {
                    focusPandoraView
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                } else if selectedTab == .settings {
                    settingsView
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard focusPandoraIsRunning, focusPandoraRemainingSec > 0 else { return }
            focusPandoraRemainingSec -= 1
            if focusPandoraRemainingSec == 0 { stopFocusPandora() }
        }
        .onChange(of: selectedTabRaw) { _, new in
            if new != IslandTab.tasks.rawValue, isComposingTask {
                cancelInput()
            }
        }
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

    private func notchPanelBackground(cornerRadius: CGFloat = 14) -> some View {
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

    private func notchSubpanelBackground(cornerRadius: CGFloat = 11) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.047))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.082), lineWidth: 1)
            )
    }

    // MARK: - Welcome

    private var welcomeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            welcomeHeroBlock
            welcomeFeatureStrip
            welcomeStatusStrip
            welcomeFooterStrip
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(notchPanelBackground(cornerRadius: 15))
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
            welcomeFeatureCell(
                icon: "keyboard",
                title: "Keys"
            )
            welcomeFeatureCell(
                icon: "checklist",
                title: "Tasks"
            )
            welcomeFeatureCell(
                icon: "menubar.rectangle",
                title: "HUD"
            )
            welcomeFeatureCell(
                icon: "timer",
                title: "Focus"
            )
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
        .background(notchSubpanelBackground(cornerRadius: 10))
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
        .background(notchSubpanelBackground(cornerRadius: 10))
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

    // MARK: - Settings

    private var settingsView: some View {
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

            VStack(spacing: 7) {
                settingsInfoRow(
                    icon: "keyboard",
                    title: "Capture",
                    value: keyboardMonitor.statusLine,
                    accent: welcomeStatusColor
                )

                Button {
                    keyboardMonitor.openAccessibilitySettings()
                } label: {
                    settingsInfoRow(
                        icon: "hand.raised",
                        title: "Accessibility",
                        value: accessibilityStatusText,
                        accent: welcomeStatusColor,
                        showsArrow: true
                    )
                }
                .buttonStyle(.plain)

                settingsInfoRow(
                    icon: "timer",
                    title: "Default focus",
                    value: "\(focusPandoraMinutes) minutes",
                    accent: Color.white.opacity(0.55)
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(notchPanelBackground(cornerRadius: 15))
    }

    private var accessibilityStatusText: String {
        switch keyboardMonitor.authorization {
        case .authorized:
            return "Allowed"
        case .missingAccessibility:
            return "Needs permission"
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
        .background(notchSubpanelBackground(cornerRadius: 12))
    }

    // MARK: - Focus Pandora

    private var focusPandoraView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Focus")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .tracking(0.45)
                Text(focusPandoraIsRunning ? "COUNTING DOWN" : "READY")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(focusPandoraIsRunning ? Color.white.opacity(0.58) : PandoraChrome.muted)
                    .tracking(0.5)
                Spacer(minLength: 0)
                Text("\(focusPandoraMinutes)m")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.055)))
            }

            HStack(alignment: .center, spacing: 12) {
                focusPandoraProgressMark

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text("Pandora")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(PandoraChrome.muted)
                            .tracking(0.4)
                        Circle()
                            .fill(focusPandoraIsRunning ? Color.white.opacity(0.72) : PandoraChrome.dim)
                            .frame(width: 4, height: 4)
                            .scaleEffect(focusPandoraIsRunning && focusPandoraPulse ? 1.8 : 1)
                            .opacity(focusPandoraIsRunning && focusPandoraPulse ? 0.45 : 1)
                    }

                    Text(focusPandoraTimeString)
                        .font(.system(size: 25, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(
                            focusPandoraRemainingSec == 0
                                ? PandoraChrome.dim
                                : PandoraChrome.primary
                        )
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                focusPandoraControlButton(
                    icon: "arrow.counterclockwise",
                    size: 12,
                    label: "Reset timer",
                    action: resetFocusPandora
                )

                focusPandoraControlButton(
                    icon: focusPandoraIsRunning ? "pause.fill" : "play.fill",
                    size: 17,
                    label: focusPandoraIsRunning ? "Pause" : "Start",
                    isPrimary: true,
                    action: toggleFocusPandora
                )
                .scaleEffect(focusPandoraIsRunning && focusPandoraPulse ? 1.06 : 1)
            }
            .padding(10)
            .background(notchSubpanelBackground(cornerRadius: 13))

            HStack(spacing: 5) {
                ForEach(focusPandoraPresets, id: \.self) { minutes in
                    focusPandoraPresetChip(minutes: minutes)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(notchPanelBackground(cornerRadius: 15))
        .animation(
            focusPandoraIsRunning
                ? .easeInOut(duration: 0.75).repeatForever(autoreverses: true)
                : .easeOut(duration: 0.18),
            value: focusPandoraPulse
        )
        .animation(.easeInOut(duration: 0.24), value: focusPandoraRemainingSec)
    }

    private var focusPandoraPresets: [Int] { [5, 15, 25, 45] }

    private var focusPandoraProgress: CGFloat {
        guard focusPandoraMinutes > 0 else { return 0 }
        let total = CGFloat(focusPandoraMinutes * 60)
        return max(0, min(1, CGFloat(focusPandoraRemainingSec) / total))
    }

    private var focusPandoraProgressMark: some View {
        ZStack {
            Circle()
                .stroke(PandoraChrome.divider, lineWidth: 2)
            Circle()
                .trim(from: 0, to: focusPandoraProgress)
                .stroke(
                    PandoraChrome.primary,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .opacity(focusPandoraRemainingSec == 0 ? 0.25 : 0.9)
            Image(systemName: focusPandoraIsRunning ? "hourglass" : "timer")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(focusPandoraIsRunning ? PandoraChrome.primary : PandoraChrome.muted)
                .symbolEffect(.pulse, options: .repeating, value: focusPandoraIsRunning)
        }
        .frame(width: 34, height: 34)
        .scaleEffect(focusPandoraIsRunning && focusPandoraPulse ? 1.04 : 1)
    }

    private var focusPandoraTimeString: String {
        let m = focusPandoraRemainingSec / 60
        let s = focusPandoraRemainingSec % 60
        return String(format: "%d:%02d", m, s)
    }

    private func focusPandoraPresetChip(minutes: Int) -> some View {
        let selected = focusPandoraMinutes == minutes
        return Button {
            selectFocusPandoraPreset(minutes)
        } label: {
            Text("\(minutes)m")
                .font(.system(size: 9, weight: selected ? .bold : .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(selected ? PandoraChrome.primary : PandoraChrome.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(selected ? Color.white.opacity(0.11) : Color.white.opacity(0.035))
                )
                .overlay(
                    Capsule()
                        .stroke(selected ? Color.white.opacity(0.2) : Color.white.opacity(0.07), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(minutes) minutes")
    }

    private func focusPandoraControlButton(
        icon: String,
        size: CGFloat,
        label: String,
        isPrimary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: isPrimary ? .semibold : .regular))
                .foregroundStyle(isPrimary ? PandoraChrome.primary : PandoraChrome.muted)
                .frame(width: isPrimary ? 34 : 28, height: 30)
                .background(
                    Circle()
                        .fill(isPrimary ? Color.white.opacity(0.1) : Color.white.opacity(0.04))
                )
                .overlay(
                    Circle()
                        .stroke(isPrimary ? Color.white.opacity(0.18) : Color.white.opacity(0.07), lineWidth: 1)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func toggleFocusPandora() {
        if focusPandoraRemainingSec == 0, !focusPandoraIsRunning {
            focusPandoraRemainingSec = focusPandoraMinutes * 60
        }

        withAnimation(.easeInOut(duration: 0.18)) {
            focusPandoraIsRunning.toggle()
            focusPandoraPulse = focusPandoraIsRunning
        }
    }

    private func resetFocusPandora() {
        withAnimation(.easeInOut(duration: 0.18)) {
            focusPandoraIsRunning = false
            focusPandoraPulse = false
            focusPandoraRemainingSec = focusPandoraMinutes * 60
        }
    }

    private func selectFocusPandoraPreset(_ minutes: Int) {
        withAnimation(.easeInOut(duration: 0.18)) {
            focusPandoraIsRunning = false
            focusPandoraPulse = false
            focusPandoraMinutes = minutes
            focusPandoraRemainingSec = minutes * 60
        }
    }

    private func stopFocusPandora() {
        withAnimation(.easeOut(duration: 0.18)) {
            focusPandoraIsRunning = false
            focusPandoraPulse = false
        }
    }

    // MARK: - Tasks

    private var tasksView: some View {
        VStack(alignment: .leading, spacing: 12) {
            tasksHeader

            if tasks.isEmpty && !isComposingTask {
                emptyTasksView
            } else {
                let pending = tasks.filter { !$0.isCompleted }
                let done    = tasks.filter { $0.isCompleted }

                if !pending.isEmpty {
                    taskSectionLabel(title: "To do", count: pending.count, accent: .white)
                    ForEach(pending) { task in taskRow(task) }
                }

                if !done.isEmpty {
                    if !pending.isEmpty { sectionDivider }
                    taskSectionLabel(
                        title: "Done",
                        count: done.count,
                        accent: Color.white.opacity(0.4)
                    )
                    ForEach(done) { task in taskRow(task) }
                }
            }

            if isComposingTask {
                addTaskField
            } else {
                addTaskButton
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(notchPanelBackground(cornerRadius: 15))
    }

    private var tasksHeader: some View {
        let pendingCount = tasks.filter { !$0.isCompleted }.count
        let completedCount = tasks.count - pendingCount

        return HStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                Image(systemName: "checklist")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.76))
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("Tasks")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.94))
                Text(pendingCount == 0 ? "Nothing pending" : "\(pendingCount) pending")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(IslandChrome.subtext)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            HStack(spacing: 5) {
                Text("\(tasks.count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                Text(completedCount > 0 ? "total" : "items")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.38))
            }
            .foregroundStyle(Color.white.opacity(0.7))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.white.opacity(0.055)))
        }
    }

    // MARK: - Task sections

    private func taskSectionLabel(title: String, count: Int, accent: Color) -> some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(accent.opacity(0.9))
            Text("\(count)")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.3))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                )
        }
        .padding(.top, 2)
    }

    private var sectionDivider: some View {
        RoundedRectangle(cornerRadius: 0.5)
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
            .padding(.vertical, 4)
    }

    // MARK: - Empty state

    private var emptyTasksView: some View {
        VStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.white.opacity(0.045))
                    .frame(width: 42, height: 42)
                Image(systemName: "tray")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.34))
            }
            VStack(spacing: 3) {
                Text("Your list is clear")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.9))
                Text("Tap below to add something to remember")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(notchSubpanelBackground(cornerRadius: 13))
    }

    // MARK: - Task row

    private func taskRow(_ task: IslandTask) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button { toggleTask(task) } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(
                        task.isCompleted
                            ? Color.cyan.opacity(0.7)
                            : Color.white.opacity(0.45)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 0)

            Text(task.title)
                .font(.system(size: 12, weight: .medium, design: .default))
                .foregroundStyle(
                    task.isCompleted
                        ? Color.white.opacity(0.36)
                        : Color.white.opacity(0.95)
                )
                .strikethrough(task.isCompleted, color: Color.white.opacity(0.3))
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button { deleteTask(task) } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(Color.white.opacity(0.22))
            }
            .buttonStyle(.plain)
            .padding(.top, 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(task.isCompleted ? Color.white.opacity(0.035) : Color.white.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(task.isCompleted ? Color.white.opacity(0.055) : Color.white.opacity(0.09), lineWidth: 1)
        )
    }

    // MARK: - Add task controls

    private var addTaskButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { isComposingTask = true }
            isInputFocused = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("Add a task")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.white.opacity(0.75))
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(notchSubpanelBackground(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var addTaskField: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.cyan.opacity(0.5))
                .padding(.top, 1)

            TextField(
                "",
                text: $newTaskTitle,
                prompt: Text("What needs to be done?")
                    .foregroundColor(Color.white.opacity(0.32)),
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .lineLimit(8)
            .focused($isInputFocused)
            .onKeyPress(.escape) { cancelInput(); return .handled }

            Button(action: commitNewTask) {
                Image(systemName: "return")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(
                        newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.white.opacity(0.20)
                            : Color.white.opacity(0.80)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 1)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.cyan.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func toggleTask(_ task: IslandTask) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            tasks[idx].isCompleted.toggle()
        }
        TaskStorage.save(tasks)
    }

    private func deleteTask(_ task: IslandTask) {
        withAnimation(.easeInOut(duration: 0.2)) {
            tasks.removeAll { $0.id == task.id }
        }
        TaskStorage.save(tasks)
    }

    private func commitNewTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { cancelInput(); return }
        withAnimation(.easeInOut(duration: 0.2)) {
            tasks.insert(IslandTask(title: title), at: 0)
        }
        TaskStorage.save(tasks)
        newTaskTitle = ""
        isComposingTask = false
        isInputFocused = false
    }

    private func cancelInput() {
        newTaskTitle = ""
        withAnimation(.easeInOut(duration: 0.18)) { isComposingTask = false }
        isInputFocused = false
    }
}
