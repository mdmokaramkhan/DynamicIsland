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
    static let key = AppSettings.Key.tasksV1

    static func load() -> [IslandTask] {
        UserDefaultsTaskRepository(key: key).load()
    }

    static func save(_ tasks: [IslandTask]) {
        UserDefaultsTaskRepository(key: key).save(tasks)
    }
}
