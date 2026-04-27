//
//  IslandTasksTabView.swift
//  DynamicIsland
//

import SwiftUI

struct IslandTasksTabView: View {
    @Binding var tasks: [IslandTask]
    @Binding var isComposingTask: Bool
    private let taskRepository: TaskRepository

    @State private var newTaskTitle = ""
    @FocusState private var isInputFocused: Bool

    init(tasks: Binding<[IslandTask]>, isComposingTask: Binding<Bool>, taskRepository: TaskRepository = UserDefaultsTaskRepository()) {
        _tasks = tasks
        _isComposingTask = isComposingTask
        self.taskRepository = taskRepository
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            tasksHeader

            if tasks.isEmpty && !isComposingTask {
                emptyTasksView
            } else {
                let pending = tasks.filter { !$0.isCompleted }
                let done = tasks.filter { $0.isCompleted }

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
        .background(IslandPanelBackground.notchPanel(cornerRadius: 15))
        .onChange(of: isComposingTask) { _, composing in
            if !composing {
                newTaskTitle = ""
                isInputFocused = false
            }
        }
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
        .background(IslandPanelBackground.notchSubpanel(cornerRadius: 13))
    }

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
            .background(IslandPanelBackground.notchSubpanel(cornerRadius: 12))
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

    private func toggleTask(_ task: IslandTask) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            tasks[idx].isCompleted.toggle()
        }
        taskRepository.save(tasks)
    }

    private func deleteTask(_ task: IslandTask) {
        withAnimation(.easeInOut(duration: 0.2)) {
            tasks.removeAll { $0.id == task.id }
        }
        taskRepository.save(tasks)
    }

    private func commitNewTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { cancelInput(); return }
        withAnimation(.easeInOut(duration: 0.2)) {
            tasks.insert(IslandTask(title: title), at: 0)
        }
        taskRepository.save(tasks)
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

#Preview("Tasks") {
    @Previewable @State var tasks: [IslandTask] = [
        IslandTask(title: "Ship the island update", isCompleted: false),
        IslandTask(title: "Earlier task", isCompleted: true),
    ]
    @Previewable @State var composing = false
    IslandTasksTabView(tasks: $tasks, isComposingTask: $composing)
        .frame(width: 400, alignment: .leading)
        .padding(16)
        .background(Color.black)
        .preferredColorScheme(.dark)
}
