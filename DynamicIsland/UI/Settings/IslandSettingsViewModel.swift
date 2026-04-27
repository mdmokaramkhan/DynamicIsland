import Combine
import SwiftUI

@MainActor
final class IslandSettingsViewModel: ObservableObject {
    @Published var selectedPane: SettingsPane = .general
    @Published var splitColumnVisibility: NavigationSplitViewVisibility = .all
}

enum SettingsPane: String, CaseIterable, Identifiable, Hashable {
    case general, media, appearance, focus, shortcuts, permissions, advanced
    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:     return "General"
        case .media:       return "Media"
        case .appearance:  return "Appearance"
        case .focus:       return "Focus"
        case .shortcuts:   return "Shortcuts"
        case .permissions: return "Privacy"
        case .advanced:    return "Advanced"
        }
    }

    var subtitle: String {
        switch self {
        case .general:     return "Island behavior"
        case .media:       return "Music controls"
        case .appearance:  return "Shape and position"
        case .focus:       return "Focus timer"
        case .shortcuts:   return "Hotkeys"
        case .permissions: return "System access"
        case .advanced:    return "Diagnostics"
        }
    }

    var symbol: String {
        switch self {
        case .general:     return "sparkles"
        case .media:       return "music.note.list"
        case .appearance:  return "sun.max"
        case .focus:       return "timer"
        case .shortcuts:   return "keyboard"
        case .permissions: return "lock.shield"
        case .advanced:    return "gearshape.2"
        }
    }

    var iconColors: [Color] {
        switch self {
        case .general:     return [Color(red:0.48,green:0.43,blue:0.98), Color(red:0.35,green:0.78,blue:0.98)]
        case .media:       return [Color(red:1.00,green:0.22,blue:0.37), Color(red:1.00,green:0.42,blue:0.62)]
        case .appearance:  return [Color(red:1.00,green:0.62,blue:0.04), Color(red:1.00,green:0.80,blue:0.01)]
        case .focus:       return [Color(red:0.19,green:0.82,blue:0.35), Color(red:0.11,green:0.75,blue:0.33)]
        case .shortcuts:   return [Color(red:0.04,green:0.52,blue:1.00), Color(red:0.00,green:0.48,blue:1.00)]
        case .permissions: return [Color(red:0.19,green:0.82,blue:0.35), Color(red:0.06,green:0.43,blue:0.34)]
        case .advanced:    return [Color(red:0.39,green:0.39,blue:0.40), Color(red:0.23,green:0.23,blue:0.24)]
        }
    }
}
