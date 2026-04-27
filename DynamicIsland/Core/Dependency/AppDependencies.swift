import Foundation

@MainActor
final class AppDependencies {
    static let shared = AppDependencies()

    let musicController: MusicControlling
    let focusTimer: FocusTiming
    let permissionProvider: PermissionProviding
    let taskRepository: TaskRepository

    private init(
        musicController: MusicControlling = MusicManager.shared,
        focusTimer: FocusTiming = FocusPandoraTimer.shared,
        permissionProvider: PermissionProviding = PermissionManager.shared,
        taskRepository: TaskRepository = UserDefaultsTaskRepository()
    ) {
        self.musicController = musicController
        self.focusTimer = focusTimer
        self.permissionProvider = permissionProvider
        self.taskRepository = taskRepository
    }
}
