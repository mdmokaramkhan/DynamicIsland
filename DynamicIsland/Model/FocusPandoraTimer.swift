//
//  FocusPandoraTimer.swift
//  DynamicIsland
//

import AppKit
import Combine
import Foundation

@MainActor
final class FocusPandoraTimer: ObservableObject {
    enum Phase: String {
        case focus
        case breakTime

        var title: String {
            switch self {
            case .focus: return "Focus"
            case .breakTime: return "Break"
            }
        }

        var symbol: String {
            switch self {
            case .focus: return "hourglass"
            case .breakTime: return "cup.and.saucer.fill"
            }
        }
    }

    static let shared = FocusPandoraTimer()
    private let settings: FocusSettingsStore
    private let musicController: MusicControlling

    @Published private(set) var phase: Phase = .focus
    @Published private(set) var remainingSec: Int
    @Published private(set) var isRunning: Bool = false
    @Published var pulse: Bool = false
    @Published private(set) var completedFocusSessions: Int = 0

    private var ticker: AnyCancellable?
    private var lastTickDate: Date?

    private init(
        settings: FocusSettingsStore = FocusSettingsStore(),
        musicController: MusicControlling = MusicManager.shared
    ) {
        self.settings = settings
        self.musicController = musicController
        remainingSec = max(1, settings.defaultMinutes * 60)
    }

    var defaultMinutes: Int {
        settings.defaultMinutes
    }

    var breakMinutes: Int {
        settings.breakMinutes
    }

    var autoStartBreak: Bool {
        settings.autoStartBreak
    }

    var pauseMediaOnFocus: Bool {
        settings.pauseMediaOnFocus
    }

    var endSound: Bool {
        settings.endSound
    }

    var longBreakInterval: Int {
        settings.longBreakInterval
    }

    var focusDND: Bool {
        settings.focusDnd
    }

    var currentTotalSeconds: Int {
        switch phase {
        case .focus:
            return max(1, defaultMinutes * 60)
        case .breakTime:
            return max(1, currentBreakMinutes * 60)
        }
    }

    var progress: Double {
        let total = Double(currentTotalSeconds)
        guard total > 0 else { return 0 }
        return max(0, min(1, Double(remainingSec) / total))
    }

    var timeString: String {
        let m = remainingSec / 60
        let s = remainingSec % 60
        return String(format: "%d:%02d", m, s)
    }

    var compactStatus: String {
        "\(phase.title) \(timeString)"
    }

    var sessionSummary: String {
        switch phase {
        case .focus:
            return "Session \(completedFocusSessions + 1)"
        case .breakTime:
            return autoStartBreak ? "Auto break" : "Break ready"
        }
    }

    var currentBreakMinutes: Int {
        let sessionNumber = max(1, completedFocusSessions)
        let isLongBreak = sessionNumber % longBreakInterval == 0
        return isLongBreak ? min(60, max(breakMinutes, breakMinutes * 3)) : breakMinutes
    }

    func toggle() {
        if isRunning {
            pause()
        } else {
            start()
        }
    }

    func start() {
        if remainingSec <= 0 {
            remainingSec = currentTotalSeconds
        }

        if phase == .focus, pauseMediaOnFocus, musicController.isPlaying {
            musicController.playPause()
        }

        isRunning = true
        pulse = true
        lastTickDate = Date()
        startTickerIfNeeded()
    }

    func pause() {
        applyElapsedTime()
        isRunning = false
        pulse = false
        ticker?.cancel()
        ticker = nil
        lastTickDate = nil
    }

    func reset() {
        isRunning = false
        pulse = false
        ticker?.cancel()
        ticker = nil
        lastTickDate = nil
        remainingSec = currentTotalSeconds
    }

    func selectFocusMinutes(_ minutes: Int) {
        settings.setDefaultMinutes(minutes)
        phase = .focus
        isRunning = false
        pulse = false
        ticker?.cancel()
        ticker = nil
        lastTickDate = nil
        remainingSec = max(1, minutes * 60)
    }

    func syncSettingsIfIdle() {
        guard !isRunning else { return }
        remainingSec = currentTotalSeconds
    }

    private func startTickerIfNeeded() {
        guard ticker == nil else { return }
        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
    }

    private func tick() {
        guard isRunning else { return }
        applyElapsedTime()
        if remainingSec <= 0 {
            completeCurrentPhase()
        }
    }

    private func applyElapsedTime() {
        let now = Date()
        guard let lastTickDate else {
            self.lastTickDate = now
            return
        }
        let elapsed = max(1, Int(now.timeIntervalSince(lastTickDate).rounded(.down)))
        remainingSec = max(0, remainingSec - elapsed)
        self.lastTickDate = now
    }

    private func completeCurrentPhase() {
        if endSound {
            NSSound.beep()
        }

        switch phase {
        case .focus:
            completedFocusSessions += 1
            phase = .breakTime
            remainingSec = currentTotalSeconds
            if autoStartBreak {
                isRunning = true
                pulse = true
                lastTickDate = Date()
            } else {
                isRunning = false
                pulse = false
                ticker?.cancel()
                ticker = nil
                lastTickDate = nil
            }
        case .breakTime:
            phase = .focus
            remainingSec = currentTotalSeconds
            isRunning = false
            pulse = false
            ticker?.cancel()
            ticker = nil
            lastTickDate = nil
        }
    }

}
