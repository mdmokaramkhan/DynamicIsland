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
        case .missingInputMonitoring:
            return "Keyboard: Input Monitoring required"
        }
    }

    private let permissionService = KeyboardPermissionService()
    private var eventTap: CFMachPort?
    private var eventTapRunLoopSource: CFRunLoopSource?
    private var fallbackMonitor: Any?

    func start() {
        stop()

        // Accessibility can be prompted. Input Monitoring must be enabled by user in Settings.
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

        if installFallbackMonitor() {
            authorization = .missingInputMonitoring
            fallbackMessage = "Enable Input Monitoring for full global capture."
            postStatusChange()
            return
        }

        authorization = .missingInputMonitoring
        isCapturing = false
        fallbackMessage = "Enable Input Monitoring, then relaunch DynamicIsland."
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

        if let monitor = fallbackMonitor {
            NSEvent.removeMonitor(monitor)
            fallbackMonitor = nil
        }

        isCapturing = false
    }

    func openInputMonitoringSettings() {
        permissionService.openInputMonitoringSettings()
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

        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
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

    private func installFallbackMonitor() -> Bool {
        fallbackMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] _ in
            Task { @MainActor in
                self?.isCapturing = true
            }
        }
        return fallbackMonitor != nil
    }

    private func handleEventTapCallback(eventType: CGEventType, event: CGEvent) {
        switch eventType {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        case .keyDown, .flagsChanged:
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
