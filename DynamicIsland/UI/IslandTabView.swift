//
//  IslandTabView.swift
//  DynamicIsland
//

import SwiftUI

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

    var icon: String {
        switch self {
        case .welcome: return "sparkles"
        case .tasks:   return "checkmark.circle"
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

    private let tabContentHInset: CGFloat = 4
    private let tabContentBInset: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Tab bar — fixed height so the island doesn't jump on switch
            HStack(spacing: 6) {
                ForEach(IslandTab.allCases, id: \.self) { tabButton($0) }
                Spacer()
            }
            .frame(height: 26)

            // Tab content
            ZStack(alignment: .top) {
                switch selectedTab {
                case .welcome: welcomeView
                case .tasks:   tasksView
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, tabContentHInset)
            .padding(.bottom, tabContentBInset)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
        .onChange(of: selectedTabRaw) { _, new in
            if new != IslandTab.tasks.rawValue, isComposingTask {
                cancelInput()
            }
        }
    }

    // MARK: - Tab button

    private func tabButton(_ tab: IslandTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTabRaw = tab.rawValue }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(tab.rawValue)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(selectedTab == tab
                          ? Color.white.opacity(0.18)
                          : Color.white.opacity(0.06))
            )
            .overlay(
                Capsule()
                    .stroke(
                        selectedTab == tab
                        ? Color.white.opacity(0.32)
                        : Color.white.opacity(0.10),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(selectedTab == tab
                         ? Color.white
                         : Color.white.opacity(0.72))
    }

    // MARK: - Welcome

    private var welcomeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            welcomeHeroBlock
            welcomeFeatureStrip
            welcomeStatusStrip
            welcomeHintRow
            welcomeCreatorCard
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(IslandChrome.featureWell)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var welcomeHeroBlock: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .stroke(IslandChrome.heroRing, lineWidth: 1.5)
                    .frame(width: 50, height: 50)
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
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )
                Image(systemName: "sparkles.2")
                    .font(.system(size: 19, weight: .semibold))
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
                Text("A lightweight menu-bar companion — glance at keys, sounds, and your task list without leaving your flow.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(IslandChrome.subtext)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var welcomeFeatureStrip: some View {
        HStack(spacing: 6) {
            welcomeFeatureCell(
                icon: "keyboard",
                title: "Keys & sound",
                subtitle: "Feedback"
            )
            welcomeFeatureCell(
                icon: "checklist",
                title: "Tasks",
                subtitle: "Quick list"
            )
            welcomeFeatureCell(
                icon: "menubar.rectangle",
                title: "Top HUD",
                subtitle: "Always on top"
            )
        }
    }

    private func welcomeFeatureCell(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .center, spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(height: 30)
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(subtitle)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.38))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var welcomeStatusStrip: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(welcomeStatusColor)
                    .frame(width: 6, height: 6)
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
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Color.orange.opacity(0.95))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var welcomeStatusColor: Color {
        switch keyboardMonitor.authorization {
        case .authorized:
            return Color.mint
        case .missingAccessibility:
            return Color.orange
        }
    }

    private var welcomeHintRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.yellow.opacity(0.7))
            Text("Hover the bar at the top of the screen to open this panel. The menubar icon has more options.")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.4))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.yellow.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.yellow.opacity(0.10), lineWidth: 1)
        )
    }

    private var welcomeCreatorCard: some View {
        Link(destination: URL(string: "https://github.com/mdmokaramkhan")!) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.12),
                                    Color.white.opacity(0.05),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Built by")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.4))
                    Text("mdmokaramkhan on GitHub")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(IslandChrome.linkAccent)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            .padding(10)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(IslandChrome.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            IslandChrome.linkAccent.opacity(0.25),
                            IslandChrome.cardStroke,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private var appVersionLabel: String {
        let s = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return s.map { "v\($0)" } ?? "v—"
    }

    // MARK: - Tasks

    private var tasksView: some View {
        VStack(alignment: .leading, spacing: 8) {
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
        .padding(.horizontal, 2)
        .padding(.bottom, 2)
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
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(
                        Color.white.opacity(0.12),
                        lineWidth: 1
                    )
                    .frame(width: 48, height: 48)
                Image(systemName: "tray")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(Color.white.opacity(0.3))
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
        .padding(.vertical, 12)
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
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(task.isCompleted ? Color.white.opacity(0.04) : Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    task.isCompleted ? Color.white.opacity(0.06) : Color.white.opacity(0.1),
                    lineWidth: 1
                )
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
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.05),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.24),
                                Color.white.opacity(0.08),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
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
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(0.25),
                            Color.white.opacity(0.12),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
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
