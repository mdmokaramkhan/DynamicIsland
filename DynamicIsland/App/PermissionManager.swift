//
//  PermissionManager.swift
//  DynamicIsland
//
//  Centralised permission checking and requesting for all three
//  permission types the app needs:
//    1. Accessibility  — keyboard event monitoring (AXIsProcessTrusted)
//    2. Automation: Apple Music — AppleScript / Apple Events
//    3. Automation: Spotify    — AppleScript / Apple Events
//
//  Both controllers (AppleMusicController, SpotifyController) already have
//  com.apple.security.automation.apple-events in the entitlements, so macOS
//  will show its own system dialog the very first time we send an AE to each
//  app.  AEDeterminePermissionToAutomateTarget lets us:
//    • check the current status (askUserIfNeeded: false)
//    • proactively trigger the dialog  (askUserIfNeeded: true)
//

import AppKit
import ApplicationServices
import Combine
import Foundation

// MARK: - Status enum

enum PermissionStatus: Equatable {
    /// Permission has been granted by the user.
    case granted
    /// User explicitly denied this permission.
    case denied
    /// macOS hasn't asked the user yet (first-run).
    case notDetermined
    /// Something unexpected; show generic "check settings" message.
    case unknown
}

// MARK: - Manager

@MainActor
final class PermissionManager: ObservableObject {
    static let shared = PermissionManager()

    // MARK: Published state

    @Published private(set) var accessibility: PermissionStatus = .unknown
    @Published private(set) var appleMusicAutomation: PermissionStatus = .unknown
    @Published private(set) var spotifyAutomation: PermissionStatus = .unknown

    /// Set to true while an automation permission dialog is open.
    @Published private(set) var isRequesting: Bool = false

    // MARK: Onboarding flag

    private static let onboardingKey = AppSettings.Key.onboardingComplete

    var isOnboardingComplete: Bool {
        UserDefaults.standard.bool(forKey: Self.onboardingKey)
    }

    func markOnboardingComplete() {
        UserDefaults.standard.set(true, forKey: Self.onboardingKey)
    }

    // MARK: Init

    private init() {}

    // MARK: - Check (non-prompting) ------------------------------------------------

    /// Refresh all statuses without showing any system dialog.
    func checkAll() {
        checkAccessibility()
        Task { await checkAllAutomation() }
    }

    func checkAccessibility() {
        accessibility = AXIsProcessTrustedWithOptions(nil) ? .granted : .notDetermined
    }

    func checkAllAutomation() async {
        async let music = Self.automationStatus(for: "com.apple.Music")
        async let spotify = Self.automationStatus(for: "com.spotify.client")
        let (m, s) = await (music, spotify)
        appleMusicAutomation = m
        spotifyAutomation = s
    }

    // MARK: - Request (prompting) --------------------------------------------------

    /// Prompts via System Settings; the user must manually toggle the switch.
    func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
        let opts = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
        // Open the pref pane so they can see the toggle immediately.
        openSettings("Privacy_Accessibility")
    }

    /// Triggers macOS's own "Allow DynamicIsland to control Apple Music?" dialog.
    func requestAppleMusicAutomation() async {
        await requestAutomation(
            bundleID: "com.apple.Music",
            write: { [weak self] s in self?.appleMusicAutomation = s }
        )
    }

    /// Triggers macOS's own "Allow DynamicIsland to control Spotify?" dialog.
    func requestSpotifyAutomation() async {
        await requestAutomation(
            bundleID: "com.spotify.client",
            write: { [weak self] s in self?.spotifyAutomation = s }
        )
    }

    // MARK: - Open settings shortcut ----------------------------------------------

    func openAutomationSettings() { openSettings("Privacy_Automation") }
    func openAccessibilitySettings() { openSettings("Privacy_Accessibility") }

    // MARK: - Convenience ----------------------------------------------------------

    /// True when Accessibility is the only missing critical permission.
    var accessibilityMissing: Bool { accessibility != .granted }

    /// True when either music automation status is not .granted.
    var automationMissing: Bool {
        appleMusicAutomation != .granted || spotifyAutomation != .granted
    }

    /// True when every permission needed for the full feature set is granted.
    var allGranted: Bool { !accessibilityMissing && !automationMissing }

    // MARK: - Private helpers -------------------------------------------------------

    private func requestAutomation(
        bundleID: String,
        write: @MainActor @escaping (PermissionStatus) -> Void
    ) async {
        isRequesting = true
        let status = await Self.requestAutomationPermission(for: bundleID)
        write(status)
        isRequesting = false
    }

    // Run off main thread — AEDeterminePermissionToAutomateTarget can block.
    nonisolated static func automationStatus(for bundleID: String) async -> PermissionStatus {
        await Task.detached(priority: .userInitiated) {
            Self.syncAutomationStatus(for: bundleID, askUser: false)
        }.value
    }

    nonisolated static func requestAutomationPermission(for bundleID: String) async -> PermissionStatus {
        await Task.detached(priority: .userInitiated) {
            Self.syncAutomationStatus(for: bundleID, askUser: true)
        }.value
    }

    /// Synchronous worker — must run off the main thread.
    private nonisolated static func syncAutomationStatus(
        for bundleID: String,
        askUser: Bool
    ) -> PermissionStatus {
        var address = AEAddressDesc()
        let createErr = bundleID.withCString { ptr in
            AECreateDesc(typeApplicationBundleID, ptr, bundleID.utf8.count, &address)
        }
        guard createErr == noErr else { return .unknown }
        defer { AEDisposeDesc(&address) }

        let permErr = AEDeterminePermissionToAutomateTarget(
            &address, typeWildCard, typeWildCard, askUser
        )

        switch permErr {
        case noErr:              return .granted
        case OSStatus(-1743):    return .denied          // errAEEventNotPermitted
        case OSStatus(-1744):    return .notDetermined   // errAEEventWouldRequireUserConsent
        default:                 return .notDetermined
        }
    }

    private func openSettings(_ anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")
        else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Convenience label helpers

extension PermissionStatus {
    var label: String {
        switch self {
        case .granted:        return "Allowed"
        case .denied:         return "Denied"
        case .notDetermined:  return "Not set"
        case .unknown:        return "Checking…"
        }
    }

    var color: String {   // system color name usable in SwiftUI via Color(_:)
        switch self {
        case .granted:        return "systemGreen"
        case .denied:         return "systemRed"
        case .notDetermined:  return "systemOrange"
        case .unknown:        return "systemGray"
        }
    }

    var isActionable: Bool { self != .granted }
}
