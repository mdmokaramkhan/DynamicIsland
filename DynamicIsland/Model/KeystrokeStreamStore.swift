import CoreGraphics
import Combine
import Foundation

@MainActor
final class KeystrokeStreamStore: ObservableObject {
    @Published private(set) var tokens: [KeystrokeToken] = []

    private let maxTokenCount: Int
    private let iconMapper: SpecialKeyIconMapper
    private var previousFlags: CGEventFlags = []

    private let trackedModifierFlags: [CGEventFlags] = [
        .maskCommand,
        .maskShift,
        .maskAlternate,
        .maskControl,
        .maskAlphaShift,
        .maskSecondaryFn
    ]

    init(maxTokenCount: Int = 12, iconMapper: SpecialKeyIconMapper = SpecialKeyIconMapper()) {
        self.maxTokenCount = maxTokenCount
        self.iconMapper = iconMapper
    }

    func process(eventType: CGEventType, event: CGEvent) {
        switch eventType {
        case .flagsChanged:
            appendModifierChangeTokens(currentFlags: event.flags)
        case .keyDown:
            appendModifierHoldTokens(currentFlags: event.flags)
            appendKeyDownToken(from: event)
        default:
            break
        }
    }

    func clear() {
        tokens.removeAll()
        previousFlags = []
    }

    private func appendModifierChangeTokens(currentFlags: CGEventFlags) {
        let changed = currentFlags.symmetricDifference(previousFlags)
        let newlyPressed = changed.intersection(currentFlags)

        for modifierFlag in trackedModifierFlags where newlyPressed.contains(modifierFlag) {
            guard let mapping = iconMapper.mappingForModifier(flag: modifierFlag) else { continue }
            append(token: .init(visual: .symbol(name: mapping.symbolName, fallback: mapping.fallbackLabel),
                                source: .modifier))
        }

        previousFlags = currentFlags
    }

    private func appendModifierHoldTokens(currentFlags: CGEventFlags) {
        for modifierFlag in trackedModifierFlags where currentFlags.contains(modifierFlag) {
            guard let mapping = iconMapper.mappingForModifier(flag: modifierFlag) else { continue }
            append(token: .init(visual: .symbol(name: mapping.symbolName, fallback: mapping.fallbackLabel),
                                source: .modifier))
        }
        previousFlags = currentFlags
    }

    private func appendKeyDownToken(from event: CGEvent) {
        let keyCodeValue = event.getIntegerValueField(.keyboardEventKeycode)
        guard let keyCode = UInt16(exactly: keyCodeValue) else { return }

        if let mapping = iconMapper.mapping(for: keyCode) {
            append(token: .init(visual: .symbol(name: mapping.symbolName, fallback: mapping.fallbackLabel),
                                source: .key))
            return
        }

        if let label = printableLabel(from: event) {
            append(token: .init(visual: .text(label), source: .key))
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

    private func append(token: KeystrokeToken) {
        tokens.append(token)
        if tokens.count > maxTokenCount {
            tokens.removeFirst(tokens.count - maxTokenCount)
        }
    }
}

private extension CGEventFlags {
    func symmetricDifference(_ other: CGEventFlags) -> CGEventFlags {
        CGEventFlags(rawValue: rawValue ^ other.rawValue)
    }

    func intersection(_ other: CGEventFlags) -> CGEventFlags {
        CGEventFlags(rawValue: rawValue & other.rawValue)
    }
}
