//
//  IslandFocusTabView.swift
//  DynamicIsland
//

import AppKit
import SwiftUI

struct IslandFocusTabView: View {
    @ObservedObject var focusTimer: FocusPandoraTimer

    @AppStorage("island.focusPandora.defaultMinutes") private var defaultMinutes: Int = 25
    @AppStorage("island.focus.breakMinutes") private var breakMinutes: Int = 5
    @AppStorage("island.focus.autoStartBreak") private var autoStartBreak: Bool = true
    @AppStorage("island.focus.dnd") private var focusDND: Bool = true
    @AppStorage("island.focus.tintRed") private var focusTintRed: Double = 1.00
    @AppStorage("island.focus.tintGreen") private var focusTintGreen: Double = 0.31
    @AppStorage("island.focus.tintBlue") private var focusTintBlue: Double = 0.12

    private var phaseTint: Color {
        let base = Color(red: focusTintRed, green: focusTintGreen, blue: focusTintBlue)
        return focusTimer.phase == .focus
            ? base
            : base.mix(with: .white, by: 0.28)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            hero
            controls
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(focusBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
        )
        .animation(.smooth(duration: 0.28), value: focusTimer.phase.rawValue)
        .animation(.easeInOut(duration: 0.24), value: focusTimer.remainingSec)
        .onAppear { focusTimer.syncSettingsIfIdle() }
        .onChange(of: defaultMinutes) { _, _ in focusTimer.syncSettingsIfIdle() }
        .onChange(of: breakMinutes) { _, _ in focusTimer.syncSettingsIfIdle() }
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: 16) {
            timerRing

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Image(systemName: focusTimer.phase.symbol)
                        .font(.system(size: 11, weight: .semibold))
                    Text(focusTimer.phase.title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                    statusDot
                }
                .foregroundStyle(Color.white.opacity(0.72))

                Text(focusTimer.timeString)
                    .font(.system(size: 38, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.white.opacity(0.94))
                    .contentTransition(.numericText())

                Text(secondaryLine)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.44))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                withAnimation(.smooth(duration: 0.2)) { focusTimer.toggle() }
            } label: {
                Image(systemName: focusTimer.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.82))
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color.white.opacity(0.88)))
                    .shadow(color: phaseTint.opacity(focusTimer.isRunning ? 0.36 : 0.16), radius: 14, y: 6)
            }
            .buttonStyle(.plain)
            .scaleEffect(focusTimer.isRunning && focusTimer.pulse ? 1.035 : 1)
            .accessibilityLabel(focusTimer.isRunning ? "Pause focus timer" : "Start focus timer")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var timerRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.11), lineWidth: 4)

            Circle()
                .trim(from: 0, to: focusTimer.progress)
                .stroke(
                    phaseTint,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: phaseTint.opacity(focusTimer.isRunning ? 0.36 : 0.12), radius: 8)

            Circle()
                .fill(phaseTint.opacity(focusTimer.isRunning ? 0.16 : 0.08))
                .frame(width: 38, height: 38)
                .scaleEffect(focusTimer.isRunning && focusTimer.pulse ? 1.08 : 1)

            Image(systemName: focusTimer.phase.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.82))
                .symbolEffect(.pulse, options: .repeating, value: focusTimer.isRunning)
        }
        .frame(width: 64, height: 64)
    }

    private var controls: some View {
        HStack(spacing: 8) {
            ForEach([5, 15, 25], id: \.self) { minutes in
                presetButton(minutes)
            }

            Button {
                withAnimation(.smooth(duration: 0.2)) { focusTimer.reset() }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 30, height: 26)
                    .background(Capsule().fill(Color.white.opacity(0.055)))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.white.opacity(0.54))
            .accessibilityLabel("Reset focus timer")
        }
    }

    private func presetButton(_ minutes: Int) -> some View {
        let selected = focusTimer.phase == .focus && focusTimer.defaultMinutes == minutes
        return Button {
            withAnimation(.smooth(duration: 0.2)) {
                focusTimer.selectFocusMinutes(minutes)
            }
        } label: {
            Text("\(minutes)m")
                .font(.system(size: 10, weight: selected ? .bold : .semibold, design: .rounded))
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                .background(Capsule().fill(selected ? phaseTint.opacity(0.18) : Color.white.opacity(0.045)))
                .overlay(
                    Capsule()
                        .strokeBorder(selected ? phaseTint.opacity(0.22) : Color.white.opacity(0.06), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? Color.white.opacity(0.92) : Color.white.opacity(0.5))
        .accessibilityLabel("\(minutes) minutes")
    }

    private var focusBackground: some View {
        ZStack {
            IslandPanelBackground.notchPanel(cornerRadius: 18)

            LinearGradient(
                colors: [
                    phaseTint.opacity(focusTimer.isRunning ? 0.28 : 0.16),
                    phaseTint.opacity(focusTimer.isRunning ? 0.10 : 0.055),
                    Color.clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    Color.clear,
                    phaseTint.opacity(focusTimer.isRunning ? 0.18 : 0.08),
                ],
                startPoint: .center,
                endPoint: .topTrailing
            )
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(focusTimer.isRunning ? phaseTint : Color.white.opacity(0.28))
            .frame(width: 5, height: 5)
            .scaleEffect(focusTimer.isRunning && focusTimer.pulse ? 1.7 : 1)
            .opacity(focusTimer.isRunning && focusTimer.pulse ? 0.5 : 1)
    }

    private var secondaryLine: String {
        var parts = [focusTimer.sessionSummary]
        if focusTimer.phase == .focus {
            parts.append("\(focusTimer.breakMinutes)m break")
        }
        if autoStartBreak {
            parts.append("auto break")
        }
        if focusDND {
            parts.append("DND")
        }
        return parts.joined(separator: " · ")
    }
}

private extension Color {
    func mix(with other: Color, by amount: Double) -> Color {
        let amount = max(0, min(1, amount))
        guard
            let lhs = NSColor(self).usingColorSpace(.deviceRGB),
            let rhs = NSColor(other).usingColorSpace(.deviceRGB)
        else { return self }

        return Color(
            red: lhs.redComponent + (rhs.redComponent - lhs.redComponent) * amount,
            green: lhs.greenComponent + (rhs.greenComponent - lhs.greenComponent) * amount,
            blue: lhs.blueComponent + (rhs.blueComponent - lhs.blueComponent) * amount
        )
    }
}

#Preview("Focus") {
    IslandFocusTabView(focusTimer: .shared)
        .frame(width: 400, alignment: .leading)
        .padding(16)
        .background(Color.black)
        .preferredColorScheme(.dark)
}
