//
//  SpotifyController.swift
//  DynamicIsland
//
//  Adapted from boringNotch (TheBoredTeam/boring.notch)
//

import AppKit
import Combine
import Foundation

final class SpotifyController: ObservableObject {
    // MARK: - Properties

    @Published private(set) var playbackState: PlaybackState = PlaybackState(
        bundleIdentifier: "com.spotify.client"
    )

    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> {
        $playbackState.eraseToAnyPublisher()
    }

    private var notificationTask: Task<Void, Never>?
    private var artworkFetchTask: Task<Void, Never>?
    private var lastArtworkURL: String?
    private var lastNotifiedSpotifyTrackID: String = ""
    private let commandDelay: Duration = .milliseconds(25)

    // MARK: - Init

    init() {
        setupObserver()
    }

    deinit {
        notificationTask?.cancel()
        artworkFetchTask?.cancel()
    }

    // MARK: - Observer

    private func setupObserver() {
        notificationTask = Task { @Sendable [weak self] in
            let notifications = DistributedNotificationCenter.default().notifications(
                named: NSNotification.Name("com.spotify.client.PlaybackStateChanged")
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
            $0.bundleIdentifier == "com.spotify.client"
        }
    }

    func togglePlay() async { await executeCommand("playpause") }
    func play() async { await executeCommand("play") }
    func pause() async { await executeCommand("pause") }
    func nextTrack() async { await executeAndRefresh("next track") }
    func previousTrack() async { await executeAndRefresh("previous track") }
    func toggleShuffle() async { await executeAndRefresh("set shuffling to not shuffling") }
    func toggleRepeat() async { await executeAndRefresh("set repeating to not repeating") }
    func seek(to time: Double) async { await executeAndRefresh("set player position to \(time)") }

    func setVolume(_ level: Double) async {
        let pct = Int(max(0, min(1, level)) * 100)
        await executeCommand("set sound volume to \(pct)")
        try? await Task.sleep(for: commandDelay)
        await updatePlaybackInfo()
    }

    private func applyNotification(_ info: [AnyHashable: Any]) async {
        let playerState = stringValue(info, ["Player State", "Playback State", "State"])
        let title = stringValue(info, ["Name", "Title", "Track Name"])
        let artist = stringValue(info, ["Artist", "Artist Name"])
        let album = stringValue(info, ["Album", "Album Name"])
        let position = numberValue(info, ["Playback Position", "Position", "Elapsed Time"]) ?? 0
        let rawDuration = numberValue(info, ["Duration", "Total Time"]) ?? 0
        let duration = rawDuration > 10_000 ? rawDuration / 1000 : rawDuration
        let artworkURL = stringValue(info, ["Artwork URL", "ArtworkURL", "Artwork Url"])
        let trackID = stringValue(info, ["Track ID", "TrackID", "Spotify Track ID"])

        let nextTitle = (title == "Unknown" || title == "Not Playing") ? "" : title
        let nextArtist = artist == "Unknown" ? "" : artist
        let nextAlbum = album == "Unknown" ? "" : album
        // Never carry the previous track's artwork to a new track; use Spotify
        // track id when present so “same name” recordings still reset art.
        let metaSame = nextTitle == playbackState.title
            && nextArtist == playbackState.artist
            && nextAlbum == playbackState.album
        let sameTrack: Bool
        if !trackID.isEmpty {
            sameTrack = (trackID == lastNotifiedSpotifyTrackID) && metaSame
        } else {
            sameTrack = metaSame
        }
        var state = PlaybackState(
            bundleIdentifier: "com.spotify.client",
            isPlaying: playerState.lowercased() == "playing",
            title: nextTitle,
            artist: nextArtist,
            album: nextAlbum,
            currentTime: position,
            duration: duration,
            playbackRate: playerState.lowercased() == "playing" ? 1 : 0,
            isShuffled: playbackState.isShuffled,
            repeatMode: playbackState.repeatMode,
            lastUpdated: Date(),
            artwork: sameTrack ? playbackState.artwork : nil,
            volume: playbackState.volume
        )

        await MainActor.run { [self] in
            self.playbackState = state
            if !trackID.isEmpty {
                self.lastNotifiedSpotifyTrackID = trackID
            } else if !metaSame {
                self.lastNotifiedSpotifyTrackID = ""
            }
        }

        if !artworkURL.isEmpty, let url = URL(string: artworkURL), artworkURL != lastArtworkURL {
            artworkFetchTask?.cancel()
            artworkFetchTask = Task {
                guard let data = try? await URLSession.shared.data(from: url).0 else { return }
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    state.artwork = data
                    self.playbackState = state
                    self.lastArtworkURL = artworkURL
                    self.artworkFetchTask = nil
                }
            }
        } else if !trackID.isEmpty, trackID != lastArtworkURL {
            fetchArtworkFromSpotifyTrackID(trackID, state: state)
        }
    }

    // MARK: - State fetch

    func updatePlaybackInfo() async {
        guard let descriptor = try? await fetchPlaybackInfo() else { return }
        guard descriptor.numberOfItems >= 10 else { return }

        let isPlaying = descriptor.atIndex(1)?.booleanValue ?? false
        let title = descriptor.atIndex(2)?.stringValue ?? ""
        let artist = descriptor.atIndex(3)?.stringValue ?? ""
        let album = descriptor.atIndex(4)?.stringValue ?? ""
        let currentTime = descriptor.atIndex(5)?.doubleValue ?? 0
        let duration = (descriptor.atIndex(6)?.doubleValue ?? 0) / 1000
        let isShuffled = descriptor.atIndex(7)?.booleanValue ?? false
        let isRepeating = descriptor.atIndex(8)?.booleanValue ?? false
        let volumePct = descriptor.atIndex(9)?.int32Value ?? 50
        let artworkURL = descriptor.atIndex(10)?.stringValue ?? ""

        let prev = await MainActor.run { self.playbackState }
        let nextT = (title == "Unknown" || title == "Not Playing") ? "" : title
        let nextA = artist == "Unknown" ? "" : artist
        let nextAl = album == "Unknown" ? "" : album
        if nextT != prev.title || nextA != prev.artist || nextAl != prev.album {
            await MainActor.run { [self] in
                self.lastNotifiedSpotifyTrackID = ""
            }
        }

        var state = PlaybackState(
            bundleIdentifier: "com.spotify.client",
            isPlaying: isPlaying,
            title: nextT,
            artist: nextA,
            album: nextAl,
            currentTime: currentTime,
            duration: duration,
            playbackRate: 1,
            isShuffled: isShuffled,
            repeatMode: isRepeating ? .all : .off,
            lastUpdated: Date(),
            artwork: nil,
            volume: Double(volumePct) / 100.0
        )

        // Reuse cached artwork if URL hasn't changed
        if artworkURL == lastArtworkURL, let cached = prev.artwork {
            state.artwork = cached
        }

        await MainActor.run { self.playbackState = state }

        if !artworkURL.isEmpty, let url = URL(string: artworkURL), artworkURL != lastArtworkURL {
            artworkFetchTask?.cancel()
            let captured = state
            artworkFetchTask = Task {
                guard let data = try? await URLSession.shared.data(from: url).0 else { return }
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    var updated = captured
                    updated.artwork = data
                    self.playbackState = updated
                    self.lastArtworkURL = artworkURL
                    self.artworkFetchTask = nil
                }
            }
        }
    }

    // MARK: - Helpers

    private func executeCommand(_ command: String) async {
        try? await AppleScriptHelper.executeVoid("tell application \"Spotify\" to \(command)")
    }

    private func executeAndRefresh(_ command: String) async {
        await executeCommand(command)
        try? await Task.sleep(for: commandDelay)
        await updatePlaybackInfo()
    }

    private func fetchPlaybackInfo() async throws -> NSAppleEventDescriptor? {
        let script = """
        tell application "Spotify"
            try
                set playerState to player state is playing
                set currentTrackName to name of current track
                set currentTrackArtist to artist of current track
                set currentTrackAlbum to album of current track
                set trackPosition to player position
                set trackDuration to duration of current track
                set shuffleState to shuffling
                set repeatState to repeating
                set currentVolume to sound volume
                set artworkURL to artwork url of current track
                return {playerState, currentTrackName, currentTrackArtist,
                        currentTrackAlbum, trackPosition, trackDuration,
                        shuffleState, repeatState, currentVolume, artworkURL}
            on error
                return {false, "Unknown", "Unknown", "Unknown", 0, 0, false, false, 50, ""}
            end try
        end tell
        """
        return try await AppleScriptHelper.execute(script)
    }

    private func fetchArtworkFromSpotifyTrackID(_ trackID: String, state: PlaybackState) {
        let urlString: String
        if trackID.hasPrefix("spotify:track:") {
            let id = trackID.replacingOccurrences(of: "spotify:track:", with: "")
            urlString = "https://open.spotify.com/track/\(id)"
        } else if trackID.hasPrefix("http") {
            urlString = trackID
        } else {
            urlString = "https://open.spotify.com/track/\(trackID)"
        }

        guard var components = URLComponents(string: "https://open.spotify.com/oembed") else { return }
        components.queryItems = [URLQueryItem(name: "url", value: urlString)]
        guard let oembedURL = components.url else { return }

        artworkFetchTask?.cancel()
        artworkFetchTask = Task {
            guard
                let data = try? await URLSession.shared.data(from: oembedURL).0,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let thumbnail = json["thumbnail_url"] as? String,
                let imageURL = URL(string: thumbnail),
                let imageData = try? await URLSession.shared.data(from: imageURL).0
            else { return }

            await MainActor.run { [weak self] in
                guard let self else { return }
                var updated = state
                updated.artwork = imageData
                self.playbackState = updated
                self.lastArtworkURL = trackID
                self.artworkFetchTask = nil
            }
        }
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
}
