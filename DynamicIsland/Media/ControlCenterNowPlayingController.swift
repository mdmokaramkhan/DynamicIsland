//
//  ControlCenterNowPlayingController.swift
//  DynamicIsland
//
//  System Now Playing via MediaRemote, isolated in a short-lived `swift` helper
//  process (some app signatures cannot read MR in-process). Parses line-delimited
//  JSON, extrapolates elapsed time using MR’s reference timestamp, and restarts
//  the helper if it exits unexpectedly.
//

import AppKit
import Combine
import Foundation
import os.log

final class ControlCenterNowPlayingController: ObservableObject {
    @Published private(set) var playbackState = PlaybackState(bundleIdentifier: "")

    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> {
        $playbackState.eraseToAnyPublisher()
    }

    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "DynamicIsland",
        category: "ControlCenterNowPlaying"
    )

    private var process: Process?
    private var outputPipe = Pipe()
    private var errorPipe = Pipe()
    private var helperURL: URL?
    private var lastEmittedSignature = ""
    private var lastPayloadDate = Date.distantPast
    private var staleTimer: Timer?
    private let parseQueue = DispatchQueue(label: "com.dynamicisland.mediaremote.parse")
    private var helperRestartCount = 0
    private let maxHelperRestarts = 20
    private var restartWorkItem: DispatchWorkItem?

    init() {
        startHelper()
        let timer = Timer(timeInterval: 1.25, repeats: true) { [weak self] _ in
            self?.clearIfStale()
        }
        RunLoop.main.add(timer, forMode: .common)
        staleTimer = timer
    }

    deinit {
        staleTimer?.invalidate()
        teardownPipesAndProcess()
        if let helperURL {
            try? FileManager.default.removeItem(at: helperURL)
        }
    }

    private func teardownPipesAndProcess() {
        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
        if process?.isRunning == true {
            process?.terminate()
        }
        process = nil
    }

    private func startHelper() {
        restartWorkItem?.cancel()
        restartWorkItem = nil
        teardownPipesAndProcess()
        outputPipe = Pipe()
        errorPipe = Pipe()
        outputBuffer.removeAll(keepingCapacity: false)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dynamicisland-mediaremote-helper-\(UUID().uuidString).swift")
        do {
            try helperSource.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            Self.log.error("Failed to write MediaRemote helper: \(String(describing: error))")
            return
        }
        helperURL = url

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        proc.arguments = [url.path]
        proc.standardOutput = outputPipe
        proc.standardError = errorPipe

        proc.terminationHandler = { [weak self] process in
            guard let self else { return }
            if process.terminationStatus != 0 && process.terminationStatus != 15 {
                Self.log.notice("MediaRemote helper exited with status \(process.terminationStatus)")
            }
            self.scheduleHelperRestartIfNeeded()
        }

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard let self else { return }
            if data.isEmpty {
                handle.readabilityHandler = nil
                self.scheduleHelperRestartIfNeeded()
                return
            }
            self.parseQueue.async { [weak self] in
                self?.consumeOutput(data)
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }

        do {
            try proc.run()
            process = proc
        } catch {
            Self.log.error("Failed to launch MediaRemote helper: \(String(describing: error))")
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            scheduleHelperRestartIfNeeded()
        }
    }

    private func scheduleHelperRestartIfNeeded() {
        guard helperRestartCount < maxHelperRestarts else {
            Self.log.error("MediaRemote helper restart limit reached; giving up")
            return
        }
        if restartWorkItem != nil { return }
        helperRestartCount += 1
        let delay = min(3.0, 0.4 * Double(helperRestartCount))
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.restartWorkItem = nil
            self.startHelper()
        }
        restartWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private var outputBuffer = Data()

    private func consumeOutput(_ data: Data) {
        outputBuffer.append(data)

        while let newline = outputBuffer.firstIndex(of: 10) {
            let line = outputBuffer.prefix(upTo: newline)
            outputBuffer.removeSubrange(...newline)
            guard !line.isEmpty else { continue }
            applyJSONLine(Data(line))
        }
    }

    private static let idleSignature = "__idle__"

    private func applyJSONLine(_ data: Data) {
        guard
            let payload = try? JSONDecoder().decode(ControlCenterPayload.self, from: data)
        else { return }

        lastPayloadDate = Date()

        let trimmedTitle = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            if lastEmittedSignature != Self.idleSignature {
                lastEmittedSignature = Self.idleSignature
                DispatchQueue.main.async {
                    self.helperRestartCount = 0
                    self.playbackState = PlaybackState(bundleIdentifier: "")
                }
            }
            return
        }

        let signature = payload.changeSignature
        if signature == lastEmittedSignature {
            return
        }
        lastEmittedSignature = signature

        var state = PlaybackState(
            bundleIdentifier: payload.bundleIdentifier,
            isPlaying: payload.isPlaying,
            title: payload.title,
            artist: payload.artist,
            album: payload.album,
            currentTime: payload.elapsedTime,
            duration: payload.duration,
            playbackRate: payload.playbackRate,
            isShuffled: payload.isShuffled,
            repeatMode: RepeatMode(rawValue: payload.repeatMode) ?? .off,
            lastUpdated: Date()
        )

        if let artworkBase64 = payload.artworkBase64,
           let artwork = Data(base64Encoded: artworkBase64) {
            state.artwork = artwork
        }

        DispatchQueue.main.async {
            self.helperRestartCount = 0
            self.playbackState = state
        }
    }

    private func clearIfStale() {
        guard !playbackState.title.isEmpty else { return }
        guard Date().timeIntervalSince(lastPayloadDate) > 3.0 else { return }

        lastEmittedSignature = ""
        DispatchQueue.main.async {
            self.playbackState = PlaybackState(bundleIdentifier: "")
        }
    }
}

private struct ControlCenterPayload: Decodable {
    let title: String
    let artist: String
    let album: String
    let duration: Double
    let elapsedTime: Double
    let playbackRate: Double
    let isPlaying: Bool
    let isShuffled: Bool
    let repeatMode: Int
    let bundleIdentifier: String
    let artworkBase64: String?

    var changeSignature: String {
        let artBits: String
        if let b64 = artworkBase64 {
            let n = b64.utf8.count
            let head = b64.prefix(48)
            artBits = "\(n)|\(head)"
        } else {
            artBits = "0|"
        }
        return [
            title, artist, album,
            String(duration), String(elapsedTime), String(playbackRate),
            String(isPlaying), String(isShuffled), String(repeatMode),
            bundleIdentifier,
            artBits
        ].joined(separator: "\u{1e}")
    }
}

private let helperSource = #"""
import AppKit
import Foundation

typealias GetNowPlayingInfoFn = @convention(c) (DispatchQueue, @escaping ([String: Any]?) -> Void) -> Void
typealias GetNowPlayingPIDFn = @convention(c) (DispatchQueue, @escaping (Int32) -> Void) -> Void

guard
    let bundle = CFBundleCreate(
        kCFAllocatorDefault,
        NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
    ),
    let pointer = CFBundleGetFunctionPointerForName(
        bundle,
        "MRMediaRemoteGetNowPlayingInfo" as CFString
    )
else {
    exit(0)
}

let getNowPlayingInfo = unsafeBitCast(pointer, to: GetNowPlayingInfoFn.self)

let getNowPlayingPID: GetNowPlayingPIDFn? = {
    guard let p = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingApplicationPID" as CFString)
    else { return nil }
    return unsafeBitCast(p, to: GetNowPlayingPIDFn.self)
}()

func raw(_ info: [String: Any], _ keys: [String]) -> Any? {
    for key in keys {
        if let value = info[key] { return value }
    }
    return nil
}

func string(_ info: [String: Any], _ keys: [String]) -> String {
    raw(info, keys) as? String ?? ""
}

func number(_ info: [String: Any], _ keys: [String]) -> Double {
    guard let value = raw(info, keys) else { return 0 }
    if let value = value as? NSNumber { return value.doubleValue }
    if let value = value as? Double { return value }
    if let value = value as? Int { return Double(value) }
    return 0
}

func data(_ info: [String: Any], _ keys: [String]) -> Data? {
    guard let value = raw(info, keys) else { return nil }
    if let value = value as? Data { return value }
    if let value = value as? NSData { return value as Data }
    return nil
}

func referenceDate(from info: [String: Any]) -> Date? {
    let keys = ["kMRMediaRemoteNowPlayingInfoTimestamp", "Timestamp", "timestamp"]
    guard let v = raw(info, keys) else { return nil }
    if let d = v as? Date { return d }
    if let d = v as? NSDate { return d as Date }
    if let n = v as? NSNumber {
        let d = n.doubleValue
        if d > 1_000_000_000_000 {
            return Date(timeIntervalSince1970: d / 1000.0)
        }
        if d > 1_000_000_000 {
            return Date(timeIntervalSince1970: d)
        }
        return Date(timeIntervalSinceReferenceDate: d)
    }
    return nil
}

func bundleIDFromInfo(_ info: [String: Any]) -> String {
    let keys = [
        "kMRMediaRemoteNowPlayingInfoNowPlayingApplicationBundleIdentifier",
        "NowPlayingApplicationBundleIdentifier",
        "kMRMediaRemoteNowPlayingInfoClientBundleIdentifier",
        "ClientBundleIdentifier",
        "MRClientPropertiesBundleIdentifier"
    ]
    let s = string(info, keys).trimmingCharacters(in: .whitespacesAndNewlines)
    if !s.isEmpty { return s }
    return ""
}

func bundleIDFromPID(_ getPID: GetNowPlayingPIDFn) -> String {
    let sem = DispatchSemaphore(value: 0)
    var pid: Int32 = 0
    getPID(DispatchQueue.global(qos: .utility)) { p in
        pid = p
        sem.signal()
    }
    _ = sem.wait(timeout: .now() + 0.35)
    guard pid > 0 else { return "" }
    let app = NSRunningApplication(processIdentifier: pid)
    return app?.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

func inferBundleIDFallback() -> String {
    let known = [
        "com.spotify.client",
        "com.apple.Music",
        "com.apple.Safari",
        "com.google.Chrome",
        "company.thebrowser.Browser",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "org.mozilla.firefox",
        "com.apple.podcasts",
        "org.videolan.vlc",
        "com.apple.TV",
        "com.apple.QuickTimePlayerX"
    ]
    let running = NSWorkspace.shared.runningApplications
    let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    if let f = front, known.contains(f) { return f }
    let set = Set(running.compactMap(\.bundleIdentifier))
    return known.first { set.contains($0) } ?? ""
}

func resolveBundleID(info: [String: Any], getPID: GetNowPlayingPIDFn?) -> String {
    let fromDict = bundleIDFromInfo(info)
    if !fromDict.isEmpty { return fromDict }
    if let getPID {
        let fromPID = bundleIDFromPID(getPID)
        if !fromPID.isEmpty { return fromPID }
    }
    return inferBundleIDFallback()
}

func shuffleOn(_ raw: Int) -> Bool {
    switch raw {
    case 2, 3: return true
    default: return false
    }
}

/// Maps MediaRemote repeat raw values to `RepeatMode` (off=1, one=2, all=3).
func repeatModeForPlaybackState(_ raw: Int) -> Int {
    switch raw {
    case 0: return 1
    case 1: return 2
    case 2: return 3
    default:
        if (1...3).contains(raw) { return raw }
        return 1
    }
}

func printIdleLine() {
    let payload: [String: Any] = [
        "title": "",
        "artist": "",
        "album": "",
        "duration": 0,
        "elapsedTime": 0,
        "playbackRate": 0,
        "isPlaying": false,
        "isShuffled": false,
        "repeatMode": 1,
        "bundleIdentifier": ""
    ]
    guard
        JSONSerialization.isValidJSONObject(payload),
        let json = try? JSONSerialization.data(withJSONObject: payload),
        let line = String(data: json, encoding: .utf8)
    else { return }
    print(line)
    fflush(stdout)
}

while true {
    let semaphore = DispatchSemaphore(value: 0)
    getNowPlayingInfo(DispatchQueue.global(qos: .utility)) { info in
        defer { semaphore.signal() }
        guard let info else {
            printIdleLine()
            return
        }

        let title = string(info, [
            "kMRMediaRemoteNowPlayingInfoTitle", "Title", "title"
        ]).trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty {
            printIdleLine()
            return
        }

        let artist = string(info, [
            "kMRMediaRemoteNowPlayingInfoArtist", "Artist", "artist"
        ])
        let album = string(info, [
            "kMRMediaRemoteNowPlayingInfoAlbum", "Album", "album"
        ])
        let duration = number(info, [
            "kMRMediaRemoteNowPlayingInfoDuration",
            "Duration", "duration",
            "MPNowPlayingInfoPropertyPlaybackDuration"
        ])
        let elapsedBase = number(info, [
            "kMRMediaRemoteNowPlayingInfoElapsedTime",
            "ElapsedTime", "elapsedTime",
            "MPNowPlayingInfoPropertyElapsedPlaybackTime"
        ])
        var rate = number(info, [
            "kMRMediaRemoteNowPlayingInfoPlaybackRate",
            "PlaybackRate", "playbackRate"
        ])
        if rate == 0 {
            rate = number(info, [
                "kMRMediaRemoteNowPlayingInfoDefaultPlaybackRate",
                "DefaultPlaybackRate", "defaultPlaybackRate"
            ])
        }

        let refDate = referenceDate(from: info) ?? Date()
        let now = Date()
        let drift = now.timeIntervalSince(refDate)
        let effectiveRate = rate
        let elapsed: Double
        if effectiveRate > 0 {
            var e = elapsedBase + drift * effectiveRate
            if duration > 0 { e = min(e, duration) }
            elapsed = max(0, e)
        } else {
            elapsed = max(0, elapsedBase)
        }

        let shuffleRaw = Int(number(info, [
            "kMRMediaRemoteNowPlayingInfoShuffleMode",
            "ShuffleMode", "shuffleMode"
        ]))
        let repeatRaw = Int(number(info, [
            "kMRMediaRemoteNowPlayingInfoRepeatMode",
            "RepeatMode", "repeatMode"
        ]))

        let artwork = data(info, [
            "kMRMediaRemoteNowPlayingInfoArtworkData",
            "kMRMediaRemoteNowPlayingInfoArtwork",
            "ArtworkData",
            "Artwork",
            "artworkData"
        ])

        let bundleIdentifier = resolveBundleID(info: info, getPID: getNowPlayingPID)
        let isPlaying = effectiveRate > 0

        let payload: [String: Any] = [
            "title": title,
            "artist": artist,
            "album": album,
            "duration": duration,
            "elapsedTime": elapsed,
            "playbackRate": effectiveRate,
            "isPlaying": isPlaying,
            "isShuffled": shuffleOn(shuffleRaw),
            "repeatMode": repeatModeForPlaybackState(repeatRaw),
            "bundleIdentifier": bundleIdentifier,
            "artworkBase64": artwork?.base64EncodedString() as Any
        ]

        guard
            JSONSerialization.isValidJSONObject(payload),
            let json = try? JSONSerialization.data(withJSONObject: payload),
            let line = String(data: json, encoding: .utf8)
        else { return }

        print(line)
        fflush(stdout)
    }

    _ = semaphore.wait(timeout: .now() + 0.55)
    Thread.sleep(forTimeInterval: 0.28)
}
"""#
