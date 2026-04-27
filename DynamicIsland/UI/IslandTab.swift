//
//  IslandTab.swift
//  DynamicIsland
//

import SwiftUI

enum IslandTab: String, CaseIterable {
    case media = "Now Playing"
    case tasks = "Tasks"
    case focusPandora = "Focus"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .media: return "music.note"
        case .tasks: return "checkmark.circle"
        case .focusPandora: return "hourglass"
        case .settings: return "gearshape"
        }
    }
}

enum IslandChrome {
    static let cardFill = Color.white.opacity(0.06)
    static let cardStroke = Color.white.opacity(0.12)
    static let subtext = Color.white.opacity(0.48)
    static let linkAccent = Color(red: 0.45, green: 0.78, blue: 0.95)
    static let heroRing = Color.white.opacity(0.14)
    static let featureWell = Color.white.opacity(0.045)
}

/// Neutral, minimal styling for the Focus (Pandora) timer — no accent color noise.
enum PandoraChrome {
    static let primary = Color.white.opacity(0.9)
    static let dim = Color.white.opacity(0.28)
    static let muted = Color.white.opacity(0.42)
    static let panel = Color.white.opacity(0.04)
    static let panelStroke = Color.white.opacity(0.09)
    static let divider = Color.white.opacity(0.12)
}
