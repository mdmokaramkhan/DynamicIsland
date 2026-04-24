import Foundation

struct KeystrokeToken: Identifiable, Equatable {
    enum Visual: Equatable {
        case text(String)
        case symbol(name: String, fallback: String)
    }

    enum Source: Equatable {
        case modifier
        case key
    }

    let id: UUID
    let visual: Visual
    let source: Source
    let createdAt: Date

    init(id: UUID = UUID(), visual: Visual, source: Source, createdAt: Date = Date()) {
        self.id = id
        self.visual = visual
        self.source = source
        self.createdAt = createdAt
    }
}
