import AppKit
import Combine
import CoreGraphics

extension Notification.Name {
    static let globalKeystrokeMonitorStatusChanged = Notification.Name("globalKeystrokeMonitorStatusChanged")
}

@MainActor
final class GlobalKeystrokeMonitor: ObservableObject {
    @Published private(set) var isCapturing = false
    @Published private(set) var authorization: KeyboardCaptureAuthorization = .missingAccessibility
    @Published private(set) var fallbackMessage = "Checking keyboard permissions..."
    var onEvent: ((CGEventType, CGEvent) -> Void)?

    var statusLine: String {
        switch authorization {
        case .authorized:
            return isCapturing ? "Keyboard: capturing" : "Keyboard: ready"
        case .missingAccessibility:
            return "Keyboard: Accessibility required"
        }
    }

    private let permissionService = KeyboardPermissionService()
    private var eventTap: CFMachPort?
    private var eventTapRunLoopSource: CFRunLoopSource?

    func start() {
        stop()

        // Accessibility can be prompted directly by the app.
        guard permissionService.isAccessibilityTrusted(promptIfNeeded: true) else {
            authorization = .missingAccessibility
            isCapturing = false
            fallbackMessage = "Enable Accessibility to capture global keystrokes."
            postStatusChange()
            return
        }

        authorization = .authorized
        if installEventTap() {
            fallbackMessage = ""
            postStatusChange()
            return
        }

        authorization = .authorized
        isCapturing = false
        fallbackMessage = "Keyboard capture is unavailable right now. Try restarting DynamicIsland."
        postStatusChange()
    }

    func stop() {
        if let source = eventTapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            eventTapRunLoopSource = nil
        }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }

        isCapturing = false
    }

    func openAccessibilitySettings() {
        permissionService.openAccessibilitySettings()
    }

    private func installEventTap() -> Bool {
        let callback: CGEventTapCallBack = { _, eventType, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<GlobalKeystrokeMonitor>
                .fromOpaque(userInfo)
                .takeUnretainedValue()
            Task { @MainActor in
                monitor.handleEventTapCallback(eventType: eventType, event: event)
            }
            return Unmanaged.passUnretained(event)
        }

        let mask = (1 << CGEventType.keyDown.rawValue)
                 | (1 << CGEventType.keyUp.rawValue)
                 | (1 << CGEventType.flagsChanged.rawValue)
                 | (1 << CGEventType.leftMouseDown.rawValue)
                 | (1 << CGEventType.leftMouseUp.rawValue)
                 | (1 << CGEventType.rightMouseDown.rawValue)
                 | (1 << CGEventType.rightMouseUp.rawValue)
                 | (1 << CGEventType.otherMouseDown.rawValue)
                 | (1 << CGEventType.otherMouseUp.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            return false
        }

        eventTap = tap
        eventTapRunLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isCapturing = true
        return true
    }

    private func handleEventTapCallback(eventType: CGEventType, event: CGEvent) {
        switch eventType {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        case .keyDown, .keyUp, .flagsChanged,
             .leftMouseDown, .leftMouseUp,
             .rightMouseDown, .rightMouseUp,
             .otherMouseDown, .otherMouseUp:
            isCapturing = true
            onEvent?(eventType, event)
        default:
            break
        }
    }

    private func postStatusChange() {
        NotificationCenter.default.post(name: .globalKeystrokeMonitorStatusChanged, object: self)
    }
}
