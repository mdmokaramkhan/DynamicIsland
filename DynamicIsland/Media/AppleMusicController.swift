//
//  AppleMusicController.swift
//  DynamicIsland
//
//  Adapted from boringNotch (TheBoredTeam/boring.notch)
//

import AppKit
import Combine
import Foundation

final class AppleMusicController: ObservableObject {
    // MARK: - Properties

    @Published private(set) var playbackState: PlaybackState = PlaybackState(
        bundleIdentifier: "com.apple.Music",
        playbackRate: 1
    )

    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> {
        $playbackState.eraseToAnyPublisher()
    }

    private var notificationTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        setupObserver()
    }

    deinit {
        notificationTask?.cancel()
    }

    // MARK: - Observer

    private func setupObserver() {
        notificationTask = Task { @Sendable [weak self] in
            let notifications = DistributedNotificationCenter.default().notifications(
                named: NSNotification.Name("com.apple.Music.playerInfo")
            )
            for await notification in notifications {
                if let userInfo = notification.userInfo {
                    await self?.applyNotification(userInfo)
                }
            }
        }
    }

    // MARK: - Public API

    func isActive() -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.apple.Music"
        }
    }

    func togglePlay() async { await executeCommand("playpause") }
    func play() async { await executeCommand("play") }
    func pause() async { await executeCommand("pause") }
    func nextTrack() async { await executeCommand("next track") }
    func previousTrack() async { await executeCommand("previous track") }

    func seek(to time: Double) async {
        await executeCommand("set player position to \(time)")
        await updatePlaybackInfo()
    }

    func toggleShuffle() async {
        await executeCommand("set shuffle enabled to not shuffle enabled")
        try? await Task.sleep(for: .milliseconds(150))
        await updatePlaybackInfo()
    }

    func toggleRepeat() async {
        await executeCommand("""
            if song repeat is off then
                set song repeat to all
            else if song repeat is all then
                set song repeat to one
            else
                set song repeat to off
            end if
        """)
        try? await Task.sleep(for: .milliseconds(150))
        await updatePlaybackInfo()
    }

    func setVolume(_ level: Double) async {
        let pct = Int(max(0, min(1, level)) * 100)
        await executeCommand("set sound volume to \(pct)")
        try? await Task.sleep(for: .milliseconds(150))
        await updatePlaybackInfo()
    }

    private func applyNotification(_ info: [AnyHashable: Any]) async {
        let playerState = stringValue(info, ["Player State", "State"])
        let title = stringValue(info, ["Name", "Title", "Track Name"])
        let artist = stringValue(info, ["Artist", "Artist Name"])
        let album = stringValue(info, ["Album", "Album Name"])
        let position = numberValue(info, ["Player Position", "Playback Position", "Position", "Elapsed Time"]) ?? playbackState.currentTime
        let duration = durationValue(info)

        var state = playbackState
        state.bundleIdentifier = "com.apple.Music"
        state.isPlaying = playerState.lowercased() == "playing"
        state.title = (title == "Unknown" || title == "Not Playing") ? "" : title
        state.artist = artist == "Unknown" ? "" : artist
        state.album = album == "Unknown" ? "" : album
        state.currentTime = position
        state.duration = duration ?? playbackState.duration
        state.playbackRate = state.isPlaying ? 1 : 0
        state.lastUpdated = Date()

        await MainActor.run { self.playbackState = state }
    }

    // MARK: - State fetch

    func updatePlaybackInfo() async {
        guard let descriptor = try? await fetchPlaybackInfo() else { return }
        guard descriptor.numberOfItems >= 11 else { return }

        var state = self.playbackState

        state.isPlaying = descriptor.atIndex(1)?.booleanValue ?? false
        let rawTitle = descriptor.atIndex(2)?.stringValue ?? ""
        state.title = (rawTitle == "Unknown" || rawTitle == "Not Playing") ? "" : rawTitle
        let rawArtist = descriptor.atIndex(3)?.stringValue ?? ""
        state.artist = rawArtist == "Unknown" ? "" : rawArtist
        let rawAlbum = descriptor.atIndex(4)?.stringValue ?? ""
        state.album = rawAlbum == "Unknown" ? "" : rawAlbum
        state.currentTime = descriptor.atIndex(5)?.doubleValue ?? 0
        state.duration = descriptor.atIndex(6)?.doubleValue ?? 0
        state.isShuffled = descriptor.atIndex(7)?.booleanValue ?? false
        let repeatRaw = descriptor.atIndex(8)?.int32Value ?? 1
        state.repeatMode = RepeatMode(rawValue: Int(repeatRaw)) ?? .off
        let volPct = descriptor.atIndex(9)?.int32Value ?? 50
        state.volume = Double(volPct) / 100.0
        if let artData = descriptor.atIndex(10)?.data {
            state.artwork = artData
        }
        state.isFavorite = descriptor.atIndex(11)?.booleanValue ?? false
        state.lastUpdated = Date()

        await MainActor.run { self.playbackState = state }
    }

    // MARK: - Helpers

    private func executeCommand(_ command: String) async {
        try? await AppleScriptHelper.executeVoid("tell application \"Music\" to \(command)")
    }

    private func fetchPlaybackInfo() async throws -> NSAppleEventDescriptor? {
        let script = """
        tell application "Music"
            try
                set playerState to player state is playing
                set currentTrackName to name of current track
                set currentTrackArtist to artist of current track
                set currentTrackAlbum to album of current track
                set trackPosition to player position
                set trackDuration to duration of current track
                set shuffleState to shuffle enabled
                set repeatState to song repeat
                if repeatState is off then
                    set repeatValue to 1
                else if repeatState is one then
                    set repeatValue to 2
                else if repeatState is all then
                    set repeatValue to 3
                end if
                try
                    set artData to data of artwork 1 of current track
                on error
                    set artData to ""
                end try
                set currentVolume to sound volume
                set favoriteState to favorited of current track
                return {playerState, currentTrackName, currentTrackArtist, currentTrackAlbum,
                        trackPosition, trackDuration, shuffleState, repeatValue,
                        currentVolume, artData, favoriteState}
            on error
                return {false, "Not Playing", "Unknown", "Unknown", 0, 0, false, 1, 50, "", false}
            end try
        end tell
        """
        return try await AppleScriptHelper.execute(script)
    }

    private func stringValue(_ info: [AnyHashable: Any], _ keys: [String]) -> String {
        for key in keys {
            if let value = info[key] as? String {
                return value
            }
        }
        return ""
    }

    private func numberValue(_ info: [AnyHashable: Any], _ keys: [String]) -> Double? {
        for key in keys {
            if let value = info[key] as? NSNumber {
                return value.doubleValue
            }
            if let value = info[key] as? Double {
                return value
            }
            if let value = info[key] as? Int {
                return Double(value)
            }
            if let value = info[key] as? String, let parsed = Double(value) {
                return parsed
            }
        }
        return nil
    }

    private func durationValue(_ info: [AnyHashable: Any]) -> Double? {
        if let numeric = numberValue(info, ["Total Time", "Duration", "totalTime"]) {
            return numeric > 10_000 ? numeric / 1000 : numeric
        }
        let raw = stringValue(info, ["Total Time", "Duration"])
        let parts = raw.split(separator: ":").compactMap { Double($0) }
        if parts.count == 2 {
            return parts[0] * 60 + parts[1]
        }
        if parts.count == 3 {
            return parts[0] * 3600 + parts[1] * 60 + parts[2]
        }
        return nil
    }
}
