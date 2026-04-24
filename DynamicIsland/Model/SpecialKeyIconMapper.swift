import CoreGraphics

struct SpecialKeyIconMapper {
    struct Mapping {
        let symbolName: String
        let fallbackLabel: String
    }

    func mapping(for keyCode: UInt16) -> Mapping? {
        switch keyCode {
        case 36, 76:
            return Mapping(symbolName: "return", fallbackLabel: "RETURN")
        case 48:
            return Mapping(symbolName: "arrow.left.and.right", fallbackLabel: "TAB")
        case 51:
            return Mapping(symbolName: "delete.left", fallbackLabel: "DELETE")
        case 53:
            return Mapping(symbolName: "escape", fallbackLabel: "ESC")
        case 49:
            return Mapping(symbolName: "space", fallbackLabel: "SPACE")
        case 123:
            return Mapping(symbolName: "arrow.left", fallbackLabel: "LEFT")
        case 124:
            return Mapping(symbolName: "arrow.right", fallbackLabel: "RIGHT")
        case 125:
            return Mapping(symbolName: "arrow.down", fallbackLabel: "DOWN")
        case 126:
            return Mapping(symbolName: "arrow.up", fallbackLabel: "UP")
        default:
            return nil
        }
    }

    func mappingForModifier(flag: CGEventFlags) -> Mapping? {
        switch flag {
        case .maskCommand:
            return Mapping(symbolName: "command", fallbackLabel: "CMD")
        case .maskShift:
            return Mapping(symbolName: "shift", fallbackLabel: "SHIFT")
        case .maskAlternate:
            return Mapping(symbolName: "option", fallbackLabel: "OPTION")
        case .maskControl:
            return Mapping(symbolName: "control", fallbackLabel: "CTRL")
        case .maskAlphaShift:
            return Mapping(symbolName: "capslock", fallbackLabel: "CAPS")
        case .maskSecondaryFn:
            return Mapping(symbolName: "fn", fallbackLabel: "FN")
        default:
            return nil
        }
    }

    func orderedModifierMappings(from flags: CGEventFlags) -> [Mapping] {
        let orderedFlags: [CGEventFlags] = [
            .maskCommand,
            .maskShift,
            .maskAlternate,
            .maskControl,
            .maskAlphaShift,
            .maskSecondaryFn
        ]

        return orderedFlags.compactMap { flag in
            guard flags.contains(flag) else { return nil }
            return mappingForModifier(flag: flag)
        }
    }
}
