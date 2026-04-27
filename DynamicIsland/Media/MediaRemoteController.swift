//
//  MediaRemoteController.swift
//  DynamicIsland
//
//  Uses Apple's private MediaRemote.framework only for transport commands.
//  Direct now-playing reads can return kMRMediaRemoteFrameworkErrorDomain
//  Code=3 on current macOS/signing contexts, so display state comes from app
//  distributed notifications instead.
//
//  Supports ALL media apps (Apple Music, Spotify, Podcasts, YouTube, Safari,
//  any app that posts to the system media remote).
//

import AppKit
import Foundation

final class MediaRemoteController {

    // MARK: - C function type aliases

    private typealias SendCommandFn         = @convention(c) (UInt32, AnyObject?) -> Void
    private typealias SetElapsedTimeFn      = @convention(c) (Double) -> Void
    private typealias SetShuffleModeFn      = @convention(c) (Int) -> Void
    private typealias SetRepeatModeFn       = @convention(c) (Int) -> Void

    // MARK: - Private C-function handles

    private let sendCommandFn:      SendCommandFn
    private let setElapsedTimeFn:   SetElapsedTimeFn
    private let setShuffleModeFn:   SetShuffleModeFn
    private let setRepeatModeFn:    SetRepeatModeFn

    // MARK: - Failable init

    init?() {
        guard let bundle = CFBundleCreate(
            kCFAllocatorDefault,
            NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
        ) else { return nil }

        guard
            let pSend    = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString),
            let pSeek    = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSetElapsedTime" as CFString),
            let pShuffle = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSetShuffleMode" as CFString),
            let pRepeat  = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSetRepeatMode" as CFString)
        else { return nil }

        sendCommandFn     = unsafeBitCast(pSend,    to: SendCommandFn.self)
        setElapsedTimeFn  = unsafeBitCast(pSeek,    to: SetElapsedTimeFn.self)
        setShuffleModeFn  = unsafeBitCast(pShuffle, to: SetShuffleModeFn.self)
        setRepeatModeFn   = unsafeBitCast(pRepeat,  to: SetRepeatModeFn.self)
    }

    // MARK: - Playback commands (same codes as boringNotch NowPlayingController)

    func togglePlay()     { sendCommandFn(2, nil) }
    func play()           { sendCommandFn(0, nil) }
    func pause()          { sendCommandFn(1, nil) }
    func nextTrack()      { sendCommandFn(4, nil) }
    func previousTrack()  { sendCommandFn(5, nil) }
    func seek(to t: Double) { setElapsedTimeFn(t) }

    func toggleShuffle() {
        setShuffleModeFn(3)
    }

    func toggleRepeat() {
        setRepeatModeFn(3)
    }
}
