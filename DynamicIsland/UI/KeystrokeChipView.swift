import SwiftUI

struct KeystrokeChipView: View {
    let token: KeystrokeToken

    var body: some View {
        Group {
            switch token.visual {
            case .text(let label):
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            case .symbol(let symbolName, let fallback):
                Image(systemName: symbolName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .accessibilityLabel(Text(fallback))
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 26)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.14))
        )
    }
}

#Preview {
    HStack(spacing: 8) {
        KeystrokeChipView(token: KeystrokeToken(visual: .symbol(name: "command", fallback: "CMD"), source: .modifier))
        KeystrokeChipView(token: KeystrokeToken(visual: .text("K"), source: .key))
    }
    .padding()
    .background(Color.black)
}
