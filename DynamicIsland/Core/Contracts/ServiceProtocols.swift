import Foundation

@MainActor
protocol MusicControlling: ObservableObject {
    var isPlaying: Bool { get }
    func playPause()
}

@MainActor
protocol FocusTiming: ObservableObject {
    var isRunning: Bool { get }
    var remainingSec: Int { get }
    var phase: FocusPandoraTimer.Phase { get }
    var compactStatus: String { get }
    var progress: Double { get }
    var pulse: Bool { get set }
}

@MainActor
protocol PermissionProviding: ObservableObject {
    var accessibility: PermissionStatus { get }
    var appleMusicAutomation: PermissionStatus { get }
    var spotifyAutomation: PermissionStatus { get }
    var isOnboardingComplete: Bool { get }
    var accessibilityMissing: Bool { get }
    func checkAll()
    func checkAccessibility()
    func requestAccessibility()
    func requestAppleMusicAutomation() async
    func requestSpotifyAutomation() async
}

protocol TaskRepository {
    func load() -> [IslandTask]
    func save(_ tasks: [IslandTask])
}
