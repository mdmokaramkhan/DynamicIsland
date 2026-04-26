//
//  ComboSoundPack.swift
//  DynamicIsland
//

/// Basenames (no extension) for the seven ⌘-combo roles, matching `KeystrokeSoundPlayer.load(_:)`.
struct ComboKeySounds: Equatable {
    var copy: String
    var paste: String
    var save: String
    var undo: String
    var cut: String
    var selectAll: String
    var generic: String
}

struct ComboSoundPack: Equatable, Identifiable {
    let id: String
    let title: String
    let category: String
    let sounds: ComboKeySounds

    /// Persisted when no selection exists; must match a pack in `allPacks`.
    static let defaultPackID = "classic"

    static let allPacks: [ComboSoundPack] = [
        ComboSoundPack(
            id: "classic",
            title: "Classic",
            category: "Default",
            sounds: ComboKeySounds(
                copy: "combo_gun_cocking",
                paste: "combo_rifle",
                save: "combo_nice",
                undo: "combo_aye",
                cut: "combo_duck",
                selectAll: "combo_accha_ji",
                generic: "combo_bruh"
            )
        ),
        ComboSoundPack(
            id: "loadout",
            title: "Loadout",
            category: "Combat",
            sounds: ComboKeySounds(
                copy: "combo_gun_cocking",
                paste: "combo_rifle",
                save: "combo_loadgun",
                undo: "combo_pubg_pan",
                cut: "combo_slap",
                selectAll: "combo_goat",
                generic: "combo_yo"
            )
        ),
        ComboSoundPack(
            id: "chaos",
            title: "Chaos",
            category: "Funny",
            sounds: ComboKeySounds(
                copy: "combo_fart",
                paste: "combo_duck",
                save: "combo_nice",
                undo: "combo_aye",
                cut: "combo_slap",
                selectAll: "combo_baigan",
                generic: "combo_bruh"
            )
        ),
        ComboSoundPack(
            id: "soft",
            title: "Soft",
            category: "Cute",
            sounds: ComboKeySounds(
                copy: "combo_meow_3",
                paste: "combo_pikachu_cute",
                save: "combo_pikachu",
                undo: "combo_hu_hu",
                cut: "combo_goat",
                selectAll: "combo_ghop_ghop",
                generic: "combo_pikachu"
            )
        ),
        ComboSoundPack(
            id: "desi-mix",
            title: "Desi mix",
            category: "Regional",
            sounds: ComboKeySounds(
                copy: "combo_haat_be",
                paste: "combo_baigan",
                save: "combo_accha_ji",
                undo: "combo_kaidhi_notification",
                cut: "combo_ghop_ghop",
                selectAll: "combo_fah",
                generic: "combo_hu_hu"
            )
        ),
    ]

    static func pack(withID id: String) -> ComboSoundPack {
        allPacks.first(where: { $0.id == id })
            ?? allPacks.first(where: { $0.id == defaultPackID })!
    }
}
