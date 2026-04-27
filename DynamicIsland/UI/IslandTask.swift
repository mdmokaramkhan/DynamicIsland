//
//  IslandTask.swift
//  DynamicIsland
//

import Foundation

struct IslandTask: Identifiable, Codable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
}

enum TaskStorage {
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
