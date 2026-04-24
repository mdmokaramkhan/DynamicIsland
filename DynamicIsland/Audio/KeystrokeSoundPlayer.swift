//
//  KeystrokeSoundPlayer.swift
//  DynamicIsland
//
//  Plays a matching sound for every key-down and key-up event received from
//  the global keyboard monitor. Sounds are pre-loaded at init time so
//  playback latency stays sub-millisecond.
//
//  Sound mapping
//  ─────────────
//  Key group         Down                           Up
//  ──────────────────────────────────────────────────────────────────
//  Space             space_down_01                  space_up_01
//  Return / Enter    enter_down_01                  enter_up_01
//  Delete / BkSp     backspace_down_01              backspace_up_01
//  Modifier keys     click                          click-up
//  Everything else   alpha_down_01/02/03 (round)    alpha_up_01
//  Mouse buttons     mouse_down_01                  mouse_up_01
//

import AVFoundation
import CoreGraphics

final class KeystrokeSoundPlayer {
    var isEnabled = true

    // MARK: - Key code constants

    private enum KC {
        static let space:   UInt16 = 49
        static let `return`: UInt16 = 36
        static let delete:  UInt16 = 51     // backspace
        static let fwdDel:  UInt16 = 117    // ⌦ forward delete
    }

    // MARK: - Pre-loaded players

    private let alphaDownPlayers: [AVAudioPlayer]   // round-robin
    private var alphaRoundIndex = 0

    private let alphaUp:      AVAudioPlayer?
    private let spaceDown:    AVAudioPlayer?
    private let spaceUp:      AVAudioPlayer?
    private let enterDown:    AVAudioPlayer?
    private let enterUp:      AVAudioPlayer?
    private let deleteDown:   AVAudioPlayer?
    private let deleteUp:     AVAudioPlayer?
    private let modifierDown: AVAudioPlayer?
    private let modifierUp:   AVAudioPlayer?
    private let mouseDown:    AVAudioPlayer?
    private let mouseUp:      AVAudioPlayer?

    // Tracks which modifier bits were active on the previous flagsChanged
    // event so we can detect press vs. release transitions.
    private var previousModifiers: CGEventFlags = []

    // MARK: - Init

    init() {
        alphaDownPlayers = ["alpha_down_01", "alpha_down_02", "alpha_down_03"]
            .compactMap { Self.load($0) }

        alphaUp      = Self.load("alpha_up_01")
        spaceDown    = Self.load("space_down_01")
        spaceUp      = Self.load("space_up_01")
        enterDown    = Self.load("enter_down_01")
        enterUp      = Self.load("enter_up_01")
        deleteDown   = Self.load("backspace_down_01")
        deleteUp     = Self.load("backspace_up_01")
        modifierDown = Self.load("click")
        modifierUp   = Self.load("click-up")
        mouseDown    = Self.load("mouse_down_01")
        mouseUp      = Self.load("mouse_up_01")
    }

    // MARK: - Public API

    func play(eventType: CGEventType, event: CGEvent) {
        guard isEnabled else { return }
        switch eventType {
        case .keyDown:                                      handleKeyDown(event)
        case .keyUp:                                        handleKeyUp(event)
        case .flagsChanged:                                 handleFlagsChanged(event)
        case .leftMouseDown, .rightMouseDown, .otherMouseDown: mouseDown?.restart()
        case .leftMouseUp,   .rightMouseUp,   .otherMouseUp:   mouseUp?.restart()
        default:                                            break
        }
    }

    // MARK: - Handlers

    private func handleKeyDown(_ event: CGEvent) {
        let kc = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        switch kc {
        case KC.space:              spaceDown?.restart()
        case KC.return:             enterDown?.restart()
        case KC.delete, KC.fwdDel: deleteDown?.restart()
        default:                    nextAlphaDown()
        }
    }

    private func handleKeyUp(_ event: CGEvent) {
        let kc = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        switch kc {
        case KC.space:              spaceUp?.restart()
        case KC.return:             enterUp?.restart()
        case KC.delete, KC.fwdDel: deleteUp?.restart()
        default:                    alphaUp?.restart()
        }
    }

    private func handleFlagsChanged(_ event: CGEvent) {
        let relevant: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
        let current  = event.flags.intersection(relevant)
        let previous = previousModifiers.intersection(relevant)

        if previous.isEmpty && !current.isEmpty {
            // At least one modifier just became active → press
            modifierDown?.restart()
        } else if !previous.isEmpty && current.isEmpty {
            // All monitored modifiers released → release
            modifierUp?.restart()
        }

        previousModifiers = event.flags
    }

    private func nextAlphaDown() {
        guard !alphaDownPlayers.isEmpty else { return }
        alphaDownPlayers[alphaRoundIndex % alphaDownPlayers.count].restart()
        alphaRoundIndex &+= 1
    }

    // MARK: - Helpers

    private static func load(_ name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
            return nil
        }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        return player
    }
}

private extension AVAudioPlayer {
    /// Rewind to the start and play, allowing rapid re-triggering.
    func restart() {
        currentTime = 0
        play()
    }
}
