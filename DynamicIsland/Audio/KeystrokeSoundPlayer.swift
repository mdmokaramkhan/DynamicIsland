//
//  KeystrokeSoundPlayer.swift
//  DynamicIsland
//

import AVFoundation
import CoreGraphics

final class KeystrokeSoundPlayer {
    private static let comboSoundsUserDefaultsKey = "KeystrokeComboSoundsEnabled"
    private static let comboSoundPackIDUserDefaultsKey = "KeystrokeComboSoundPackID"
    private static let mouseClickSoundsUserDefaultsKey = "KeystrokeMouseClickSoundsEnabled"

    var isEnabled = true
    var isMouseClickSoundEnabled = true {
        didSet {
            UserDefaults.standard.set(isMouseClickSoundEnabled, forKey: Self.mouseClickSoundsUserDefaultsKey)
        }
    }
    var isComboSoundEnabled = true {
        didSet {
            UserDefaults.standard.set(isComboSoundEnabled, forKey: Self.comboSoundsUserDefaultsKey)
        }
    }

    /// Persisted pack id (for menu checkmarks); falls back to default when unset.
    var activeComboSoundPackID: String {
        UserDefaults.standard.string(forKey: Self.comboSoundPackIDUserDefaultsKey)
            ?? ComboSoundPack.defaultPackID
    }

    // MARK: - Key code constants

    private enum KC {
        static let space:   UInt16 = 49
        static let `return`: UInt16 = 36
        static let delete:  UInt16 = 51
        static let fwdDel:  UInt16 = 117

        // 🔥 Combo keys
        static let c: UInt16 = 8
        static let v: UInt16 = 9
        static let z: UInt16 = 6
        static let x: UInt16 = 7
        static let a: UInt16 = 0
        static let s: UInt16 = 1
    }

    // MARK: - Pre-loaded players

    private let alphaDownPlayers: [AVAudioPlayer]
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

    private struct LoadedComboPlayers {
        var copy: AVAudioPlayer?
        var paste: AVAudioPlayer?
        var save: AVAudioPlayer?
        var undo: AVAudioPlayer?
        var cut: AVAudioPlayer?
        var selectAll: AVAudioPlayer?
        var generic: AVAudioPlayer?
    }

    private var comboPlayers: LoadedComboPlayers

    private var previousModifiers: CGEventFlags = []

    // MARK: - Init

    init() {
        if UserDefaults.standard.object(forKey: Self.mouseClickSoundsUserDefaultsKey) != nil {
            isMouseClickSoundEnabled = UserDefaults.standard.bool(forKey: Self.mouseClickSoundsUserDefaultsKey)
        }
        if UserDefaults.standard.object(forKey: Self.comboSoundsUserDefaultsKey) != nil {
            isComboSoundEnabled = UserDefaults.standard.bool(forKey: Self.comboSoundsUserDefaultsKey)
        }

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

        let initialPack = Self.resolveInitialComboPack()
        comboPlayers = Self.loadComboPlayers(for: initialPack.sounds)
    }

    // MARK: - Public API

    func applyComboPack(id: String) {
        let pack = ComboSoundPack.pack(withID: id)
        UserDefaults.standard.set(pack.id, forKey: Self.comboSoundPackIDUserDefaultsKey)
        comboPlayers = Self.loadComboPlayers(for: pack.sounds)
    }

    /// Aligns in-memory combo toggle with `UserDefaults` when the key exists (e.g. menu open after external change).
    func syncComboSoundEnabledWithUserDefaults() {
        guard UserDefaults.standard.object(forKey: Self.comboSoundsUserDefaultsKey) != nil else { return }
        let persisted = UserDefaults.standard.bool(forKey: Self.comboSoundsUserDefaultsKey)
        if persisted != isComboSoundEnabled {
            isComboSoundEnabled = persisted
        }
    }

    func syncMouseClickSoundEnabledWithUserDefaults() {
        guard UserDefaults.standard.object(forKey: Self.mouseClickSoundsUserDefaultsKey) != nil else { return }
        let persisted = UserDefaults.standard.bool(forKey: Self.mouseClickSoundsUserDefaultsKey)
        if persisted != isMouseClickSoundEnabled {
            isMouseClickSoundEnabled = persisted
        }
    }

    func play(eventType: CGEventType, event: CGEvent) {
        switch eventType {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            guard isEnabled, isMouseClickSoundEnabled else { return }
            mouseDown?.restart()

        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            guard isEnabled, isMouseClickSoundEnabled else { return }
            mouseUp?.restart()

        case .keyDown:
            guard isEnabled else { return }
            handleKeyDown(event)

        case .keyUp:
            guard isEnabled else { return }
            handleKeyUp(event)

        case .flagsChanged:
            guard isEnabled else { return }
            handleFlagsChanged(event)

        default:
            break
        }
    }

    // MARK: - Handlers

    private func handleKeyDown(_ event: CGEvent) {
        let kc = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        let isCmd   = flags.contains(.maskCommand)
        let isShift = flags.contains(.maskShift)

        // 🔥 COMBO DETECTION (FIRST PRIORITY)
        if isCmd, isComboSoundEnabled {
            switch kc {

            case KC.c:
                comboPlayers.copy?.restart()
                return

            case KC.v:
                comboPlayers.paste?.restart()
                return

            case KC.s:
                comboPlayers.save?.restart()
                return

            case KC.x:
                comboPlayers.cut?.restart()
                return

            case KC.a:
                comboPlayers.selectAll?.restart()
                return

            case KC.z:
                comboPlayers.undo?.restart()
                return

            default:
                comboPlayers.generic?.restart()
                return
            }
        }

        // 🔽 Normal key handling
        switch kc {
        case KC.space:
            spaceDown?.restart()

        case KC.return:
            enterDown?.restart()

        case KC.delete, KC.fwdDel:
            deleteDown?.restart()

        default:
            nextAlphaDown()
        }
    }

    private func handleKeyUp(_ event: CGEvent) {
        let kc = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

        switch kc {
        case KC.space:
            spaceUp?.restart()

        case KC.return:
            enterUp?.restart()

        case KC.delete, KC.fwdDel:
            deleteUp?.restart()

        default:
            alphaUp?.restart()
        }
    }

    private func handleFlagsChanged(_ event: CGEvent) {
        let relevant: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
        let current  = event.flags.intersection(relevant)
        let previous = previousModifiers.intersection(relevant)

        if previous.isEmpty && !current.isEmpty {
            modifierDown?.restart()
        } else if !previous.isEmpty && current.isEmpty {
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

    private static func resolveInitialComboPack() -> ComboSoundPack {
        guard let id = UserDefaults.standard.string(forKey: comboSoundPackIDUserDefaultsKey) else {
            return ComboSoundPack.pack(withID: ComboSoundPack.defaultPackID)
        }
        if ComboSoundPack.allPacks.contains(where: { $0.id == id }) {
            return ComboSoundPack.pack(withID: id)
        }
        UserDefaults.standard.set(ComboSoundPack.defaultPackID, forKey: comboSoundPackIDUserDefaultsKey)
        return ComboSoundPack.pack(withID: ComboSoundPack.defaultPackID)
    }

    private static func loadComboPlayers(for sounds: ComboKeySounds) -> LoadedComboPlayers {
        LoadedComboPlayers(
            copy: load(sounds.copy),
            paste: load(sounds.paste),
            save: load(sounds.save),
            undo: load(sounds.undo),
            cut: load(sounds.cut),
            selectAll: load(sounds.selectAll),
            generic: load(sounds.generic)
        )
    }

    private static func load(_ name: String) -> AVAudioPlayer? {
        let formats = ["wav", "mp3", "m4a"]

        for ext in formats {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                let player = try? AVAudioPlayer(contentsOf: url)
                player?.prepareToPlay()
                return player
            }
        }

        print("❌ Sound not found: \(name)")
        return nil
    }
}

// MARK: - Extension

private extension AVAudioPlayer {
    func restart() {
        currentTime = 0
        play()
    }
}
