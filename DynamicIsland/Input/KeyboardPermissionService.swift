import AppKit
import ApplicationServices

enum KeyboardCaptureAuthorization: Equatable {
    case authorized
    case missingAccessibility
    case missingInputMonitoring
}

struct KeyboardPermissionService {
    private var accessibilityPromptKey: CFString { "AXTrustedCheckOptionPrompt" as CFString }

    func isAccessibilityTrusted(promptIfNeeded: Bool) -> Bool {
        let options = [accessibilityPromptKey: promptIfNeeded] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func openInputMonitoringSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
