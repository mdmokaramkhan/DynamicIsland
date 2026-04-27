import AppKit
import SwiftUI

@MainActor
final class OnboardingCoordinator {
    private var onboardingWindow: NSWindow?
    private let onDismiss: () -> Void

    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    func show() {
        guard onboardingWindow == nil else { return }
        NSApp.setActivationPolicy(.regular)

        let view = PermissionOnboardingView { [weak self] in
            self?.dismiss()
        }
        let controller = NSHostingController(rootView: view)
        controller.view.frame = NSRect(x: 0, y: 0, width: 500, height: 560)

        let window = NSWindow(contentViewController: controller)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.setContentSize(NSSize(width: 500, height: 560))
        window.center()
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        onboardingWindow = window
    }

    func dismiss() {
        onboardingWindow?.close()
        onboardingWindow = nil
        onDismiss()
    }

    var isVisible: Bool {
        onboardingWindow != nil
    }
}
