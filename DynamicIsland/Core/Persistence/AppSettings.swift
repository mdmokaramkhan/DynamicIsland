import Foundation
import SwiftUI

enum AppSettings {
    enum Key {
        static let onboardingComplete = "di.permissionOnboardingComplete"
        static let selectedTab = "island.selectedTab"
        static let musicControlSlotsV1 = "island.musicControlSlots.v1"
        static let tasksV1 = "island.tasks.v1"

        static let focusDefaultMinutes = "island.focusPandora.defaultMinutes"
        static let focusBreakMinutes = "island.focus.breakMinutes"
        static let focusAutoStartBreak = "island.focus.autoStartBreak"
        static let focusPauseMedia = "island.focus.pauseMedia"
        static let focusEndSound = "island.focus.endSound"
        static let focusLongBreakInterval = "island.focus.longBreakInterval"
        static let focusDnd = "island.focus.dnd"
        static let focusTintRed = "island.focus.tintRed"
        static let focusTintGreen = "island.focus.tintGreen"
        static let focusTintBlue = "island.focus.tintBlue"

        static let appearanceShadow = "island.appearance.shadow"
    }
}

final class FocusSettingsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var defaultMinutes: Int {
        let stored = defaults.integer(forKey: AppSettings.Key.focusDefaultMinutes)
        return stored > 0 ? stored : 25
    }

    var breakMinutes: Int {
        let stored = defaults.integer(forKey: AppSettings.Key.focusBreakMinutes)
        return stored > 0 ? stored : 5
    }

    var autoStartBreak: Bool {
        defaults.object(forKey: AppSettings.Key.focusAutoStartBreak) as? Bool ?? true
    }

    var pauseMediaOnFocus: Bool {
        defaults.bool(forKey: AppSettings.Key.focusPauseMedia)
    }

    var endSound: Bool {
        defaults.object(forKey: AppSettings.Key.focusEndSound) as? Bool ?? true
    }

    var longBreakInterval: Int {
        let stored = defaults.integer(forKey: AppSettings.Key.focusLongBreakInterval)
        return stored > 0 ? stored : 4
    }

    var focusDnd: Bool {
        defaults.object(forKey: AppSettings.Key.focusDnd) as? Bool ?? true
    }

    func setDefaultMinutes(_ minutes: Int) {
        defaults.set(minutes, forKey: AppSettings.Key.focusDefaultMinutes)
    }
}
