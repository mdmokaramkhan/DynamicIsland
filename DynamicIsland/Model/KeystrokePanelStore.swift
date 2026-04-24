import AppKit
import Combine
import CoreGraphics
import Foundation

@MainActor
final class KeystrokePanelStore: ObservableObject {
    @Published private(set) var lastKeystrokeToken: KeystrokeToken?
    @Published private(set) var frontmostAppIcon: NSImage?
    @Published private(set) var lastKeystrokeAt: Date?

    private let iconMapper: SpecialKeyIconMapper

    init(iconMapper: SpecialKeyIconMapper = SpecialKeyIconMapper()) {
        self.iconMapper = iconMapper
    }

    func process(eventType: CGEventType, event: CGEvent) {
        switch eventType {
        case .flagsChanged:
            updateLastTokenFromFlagsChanged(event)
            refreshFrontmostAppIcon()
        case .keyDown:
            updateLastTokenFromKeyDown(event)
            refreshFrontmostAppIcon()
        default:
            break
        }
    }

    func clear() {
        lastKeystrokeToken = nil
        frontmostAppIcon = nil
        lastKeystrokeAt = nil
    }

    private func updateLastTokenFromFlagsChanged(_ event: CGEvent) {
        guard let modifierMapping = iconMapper.orderedModifierMappings(from: event.flags).first else {
            return
        }

        lastKeystrokeToken = .init(
            visual: .symbol(name: modifierMapping.symbolName, fallback: modifierMapping.fallbackLabel),
            source: .flagsChanged,
            keyCode: nil,
            modifierLabels: [modifierMapping.fallbackLabel]
        )
        lastKeystrokeAt = Date()
    }

    private func updateLastTokenFromKeyDown(_ event: CGEvent) {
        let keyCodeValue = event.getIntegerValueField(.keyboardEventKeycode)
        guard let keyCode = UInt16(exactly: keyCodeValue) else { return }
        let modifierLabels = iconMapper.orderedModifierMappings(from: event.flags).map(\.fallbackLabel)

        if let mapping = iconMapper.mapping(for: keyCode) {
            lastKeystrokeToken = .init(
                visual: .symbol(name: mapping.symbolName, fallback: mapping.fallbackLabel),
                source: .keyDown,
                keyCode: keyCode,
                modifierLabels: modifierLabels
            )
            lastKeystrokeAt = Date()
            return
        }

        if let label = printableLabel(from: event) {
            lastKeystrokeToken = .init(
                visual: .text(label),
                source: .keyDown,
                keyCode: keyCode,
                modifierLabels: modifierLabels
            )
            lastKeystrokeAt = Date()
        }
    }

    private func printableLabel(from event: CGEvent) -> String? {
        var characters = [UniChar](repeating: 0, count: 4)
        var actualLength: Int = 0
        event.keyboardGetUnicodeString(maxStringLength: characters.count,
                                       actualStringLength: &actualLength,
                                       unicodeString: &characters)

        guard actualLength > 0 else { return nil }
        let scalarView = characters.prefix(actualLength).compactMap(UnicodeScalar.init)
        let text = String(String.UnicodeScalarView(scalarView))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else { return nil }
        return text.uppercased()
    }

    private func refreshFrontmostAppIcon() {
        frontmostAppIcon = NSWorkspace.shared.frontmostApplication?.icon
    }
}
