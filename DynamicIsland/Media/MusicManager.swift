//
//  MusicManager.swift
//  DynamicIsland
//
//  Singleton music manager.
//
//  Display state: AppleMusicController, SpotifyController, and
//  ControlCenterNowPlayingController (system Now Playing). Playback commands
//  for non–native-app sources use MediaRemoteController when available.
//
//  Using a singleton (@ObservedObject var = .shared) instead of @StateObject
//  completely avoids the "Publishing changes from within view updates" crash.
//

import AppKit
import Combine
import SwiftUI

// MARK: - Global default artwork

private let defaultAlbumArt: NSImage =
    NSImage(systemSymbolName: "music.note", accessibilityDescription: nil) ?? NSImage()

// MARK: - MusicManager

@MainActor
final class MusicManager: ObservableObject {
    static let shared = MusicManager()

    // MARK: – Published state (mirrors boringNotch MusicManager fields)

    @Published private(set) var songTitle:    String    = ""
    @Published private(set) var artistName:   String    = ""
    @Published private(set) var albumArt:     NSImage   = defaultAlbumArt
    @Published private(set) var isPlaying:    Bool      = false
    @Published private(set) var album:        String    = ""
    @Published private(set) var isPlayerIdle: Bool      = true
    @Published private(set) var songDuration: TimeInterval = 0
    @Published private(set) var elapsedTime:  TimeInterval = 0
    @Published private(set) var timestampDate: Date     = Date()
    @Published private(set) var playbackRate:  Double   = 1
    @Published private(set) var isShuffled:    Bool     = false
    @Published private(set) var repeatMode:    RepeatMode = .off
    @Published private(set) var bundleIdentifier: String? = nil
    @Published private(set) var volume: Double = 0.5
    @Published private(set) var isFavoriteTrack: Bool = false
    /// Average colour extracted from the current album art (for UI tinting).
    @Published private(set) var avgColor: NSColor = .white
    /// True when we're using the app icon instead of real artwork.
    @Published private(set) var usingAppIconForArtwork: Bool = false
    /// System Now Playing: scrubber caps extrapolation so stale MR cannot run time forward.
    @Published private(set) var isControlCenterSource: Bool = false

    // MARK: – Private

    private enum ActiveSource { case spotify, appleMusic, controlCenter }
    private var activeSource: ActiveSource?

    // MediaRemote is command-only. Display state comes from app notifications
    // and the low-priority Control Center helper.
    private let mrController: MediaRemoteController?

    // Fallback AppleScript controllers (used when MR unavailable)
    private let spotifyController     = SpotifyController()
    private let appleMusicController  = AppleMusicController()
    private let controlCenterController = ControlCenterNowPlayingController()

    private var cancellables = Set<AnyCancellable>()
    private var artworkTaskID: String = ""   // title|artist|album — debounce track changes
    /// Hash of the last `PlaybackState.artwork` Data we applied; needed so async
    /// artwork that arrives for the *same* track is not skipped.
    private var lastAppliedArtworkDataHash: Int?
    private var controlCenterHasReported = false

    // MARK: – Init

    private init() {
        mrController = MediaRemoteController()

        // ── Apple Music / Spotify are fallback sources. They are always
        // subscribed so the UI does not get stuck on an empty MediaRemote poll.
        spotifyController.playbackStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleScript(state, from: .spotify)
            }
            .store(in: &cancellables)

        appleMusicController.playbackStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleScript(state, from: .appleMusic)
            }
            .store(in: &cancellables)

        controlCenterController.playbackStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleScript(state, from: .controlCenter)
            }
            .store(in: &cancellables)
    }

    // MARK: – AppleScript fallback handler

    private var scriptActiveSource: ActiveSource?

    private func handleScript(_ state: PlaybackState, from src: ActiveSource) {
        defer { isControlCenterSource = (activeSource == .controlCenter) }
        let clean = { (s: String) -> String in
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return (t == "Unknown" || t == "Not Playing") ? "" : t
        }
        let t = clean(state.title)
        let a = clean(state.artist)
        let al = clean(state.album)

        if src == .controlCenter {
            if t.isEmpty {
                if activeSource == .controlCenter || controlCenterHasReported {
                    clearNowPlaying()
                }
                return
            }
            controlCenterHasReported = true
        }

        guard !t.isEmpty else {
            if activeSource == src {
                clearNowPlaying()
            }
            return
        }

        if src == .controlCenter,
           activeSource == .spotify || activeSource == .appleMusic {
            let native = activeSource == .spotify
                ? spotifyController.playbackState
                : appleMusicController.playbackState
            let nt = native.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if native.isPlaying,
               !nt.isEmpty, nt != "Unknown", nt != "Not Playing" {
                return
            }
        }

        if state.isPlaying || activeSource == nil || activeSource == src {
            scriptActiveSource = src
            activeSource = src
        } else {
            return
        }

        if t  != songTitle   { songTitle   = t }
        if a  != artistName  { artistName  = a }
        if al != album       { album       = al }
        if state.isPlaying != isPlaying { isPlaying = state.isPlaying }

        // Control Center / MediaRemote: always re-apply timing on each snapshot so
        // duration, elapsed, rate, and scrubber anchor stay locked to system Now Playing.
        if src == .controlCenter {
            songDuration = state.duration
            elapsedTime = state.currentTime
            playbackRate = max(0, state.playbackRate)
            timestampDate = state.lastUpdated
        } else {
            if state.duration  != songDuration  { songDuration  = state.duration  }
            if state.currentTime != elapsedTime { elapsedTime   = state.currentTime }
            if state.lastUpdated != timestampDate { timestampDate = state.lastUpdated }
            if state.playbackRate != playbackRate { playbackRate = state.playbackRate }
        }
        if state.isShuffled   != isShuffled   { isShuffled   = state.isShuffled }
        if state.repeatMode   != repeatMode   { repeatMode   = state.repeatMode }
        if state.volume       != volume       { volume       = state.volume }
        if state.isFavorite   != isFavoriteTrack { isFavoriteTrack = state.isFavorite }
        let newBID = state.bundleIdentifier.isEmpty ? nil : state.bundleIdentifier
        if newBID != bundleIdentifier { bundleIdentifier = newBID }
        isPlayerIdle = !state.isPlaying && t.isEmpty

        let trackID = "\(t)|\(a)|\(al)"
        let trackBecameNew = trackID != artworkTaskID
        if trackBecameNew {
            artworkTaskID = trackID
            lastAppliedArtworkDataHash = nil
        }

        if let data = state.artwork, !data.isEmpty, let img = NSImage(data: data) {
            let h = MusicManager.stableDataHash(data)
            if lastAppliedArtworkDataHash != h {
                lastAppliedArtworkDataHash = h
                usingAppIconForArtwork = false
                updateAlbumArt(img)
            }
        } else if trackBecameNew {
            if let bid = newBID, !bid.isEmpty, let appImg = AppIconAsNSImage(for: bid) {
                usingAppIconForArtwork = true
                updateAlbumArt(appImg)
            } else {
                usingAppIconForArtwork = false
                updateAlbumArt(defaultAlbumArt)
            }
        }
    }

    private func clearNowPlaying() {
        songTitle = ""
        artistName = ""
        album = ""
        isPlaying = false
        isPlayerIdle = true
        songDuration = 0
        elapsedTime = 0
        playbackRate = 1
        isShuffled = false
        repeatMode = .off
        volume = 0.5
        isFavoriteTrack = false
        bundleIdentifier = nil
        usingAppIconForArtwork = false
        lastAppliedArtworkDataHash = nil
        updateAlbumArt(defaultAlbumArt)
        activeSource = nil
        scriptActiveSource = nil
        artworkTaskID = ""
        controlCenterHasReported = false
    }

    // MARK: – Album art + average colour

    private func updateAlbumArt(_ image: NSImage) {
        albumArt = image
        image.averageColor { [weak self] color in
            if let color {
                self?.avgColor = color
            }
        }
    }

    // MARK: – Playback controls

    func playPause() {
        switch activeSource {
        case .spotify:    Task { await spotifyController.togglePlay() }
        case .appleMusic: Task { await appleMusicController.togglePlay() }
        case .controlCenter: mrController?.togglePlay()
        default:
            if spotifyController.isActive() { Task { await spotifyController.togglePlay() } }
            else if appleMusicController.isActive() { Task { await appleMusicController.togglePlay() } }
            else { mrController?.togglePlay() }
        }
    }

    func nextTrack() {
        switch activeSource {
        case .spotify:    Task { await spotifyController.nextTrack() }
        case .appleMusic: Task { await appleMusicController.nextTrack() }
        case .controlCenter: mrController?.nextTrack()
        default: mrController?.nextTrack()
        }
    }

    func previousTrack() {
        switch activeSource {
        case .spotify:    Task { await spotifyController.previousTrack() }
        case .appleMusic: Task { await appleMusicController.previousTrack() }
        case .controlCenter: mrController?.previousTrack()
        default: mrController?.previousTrack()
        }
    }

    func toggleShuffle() {
        switch activeSource {
        case .spotify:    Task { await spotifyController.toggleShuffle() }
        case .appleMusic: Task { await appleMusicController.toggleShuffle() }
        case .controlCenter: mrController?.toggleShuffle()
        default: mrController?.toggleShuffle()
        }
    }

    func toggleRepeat() {
        switch activeSource {
        case .spotify:    Task { await spotifyController.toggleRepeat() }
        case .appleMusic: Task { await appleMusicController.toggleRepeat() }
        case .controlCenter: mrController?.toggleRepeat()
        default: mrController?.toggleRepeat()
        }
    }

    func seek(to position: TimeInterval) {
        switch activeSource {
        case .spotify:    Task { await spotifyController.seek(to: position) }
        case .appleMusic: Task { await appleMusicController.seek(to: position) }
        case .controlCenter: mrController?.seek(to: position)
        default: mrController?.seek(to: position)
        }
    }

    func goBackward15() {
        seek(to: max(0, estimatedPlaybackPosition() - 15))
    }

    func goForward15() {
        seek(to: min(songDuration, estimatedPlaybackPosition() + 15))
    }

    func toggleFavorite() {
        // Favorite is app-specific in boringNotch. Keep the UI state stable here
        // and leave this as a harmless no-op unless an app-specific controller is active.
    }

    // MARK: – Utility

    private static func stableDataHash(_ data: Data) -> Int {
        var hasher = Hasher()
        hasher.combine(data)
        return hasher.finalize()
    }

    /// Real-time estimated playback position (same formula as boringNotch).
    func estimatedPlaybackPosition(at date: Date = Date()) -> TimeInterval {
        guard isPlaying else { return min(elapsedTime, songDuration) }
        var delta = date.timeIntervalSince(timestampDate)
        if isControlCenterSource {
            delta = min(delta, 1.05)
        }
        return min(max(0, elapsedTime + delta * playbackRate), songDuration)
    }

    func openMusicApp() {
        guard let bid = bundleIdentifier,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid)
        else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }

    func openAutomationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
        else { return }
        NSWorkspace.shared.open(url)
    }

    var sourceLabel: String {
        guard let id = bundleIdentifier, !id.isEmpty else {
            return activeSource == .controlCenter ? "Media" : ""
        }
        if id.contains("spotify") { return "Spotify" }
        if id.contains("Music")   { return "Apple Music" }
        if id.contains("podcast") { return "Podcasts" }
        if id.contains("vlc")     { return "VLC" }
        if id.contains("Safari")  { return "Safari" }
        if id.contains("Chrome")  { return "Chrome" }
        if id.contains("Browser") { return "Browser" }
        if id.contains("edgemac") { return "Edge" }
        if id.contains("firefox") { return "Firefox" }
        if activeSource == .controlCenter { return "Media" }
        return ""
    }

    var statusLabel: String {
        if songTitle.isEmpty { return "Open a media app to see now playing" }
        return isPlaying ? "Playing on \(sourceLabel)" : "Paused on \(sourceLabel)"
    }
}
