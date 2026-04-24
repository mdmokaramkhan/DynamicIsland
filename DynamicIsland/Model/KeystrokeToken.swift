import Foundation

struct KeystrokeToken: Identifiable, Equatable {
    enum Visual: Equatable {
        case text(String)
        case symbol(name: String, fallback: String)
    }

    enum Source: Equatable { case keyDown, flagsChanged }

    let id: UUID
    let visual: Visual
    let source: Source
    let keyCode: UInt16?
    let modifierLabels: [String]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        visual: Visual,
        source: Source,
        keyCode: UInt16? = nil,
        modifierLabels: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.visual = visual
        self.source = source
        self.keyCode = keyCode
        self.modifierLabels = modifierLabels
        self.createdAt = createdAt
    }
}
