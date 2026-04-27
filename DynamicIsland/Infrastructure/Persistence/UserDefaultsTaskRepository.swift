import Foundation

struct UserDefaultsTaskRepository: TaskRepository {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = AppSettings.Key.tasksV1) {
        self.defaults = defaults
        self.key = key
    }

    func load() -> [IslandTask] {
        guard let data = defaults.data(forKey: key),
              let tasks = try? JSONDecoder().decode([IslandTask].self, from: data) else {
            return []
        }
        return tasks
    }

    func save(_ tasks: [IslandTask]) {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        defaults.set(data, forKey: key)
    }
}
