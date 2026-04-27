//
//  IslandFocusTabView.swift
//  DynamicIsland
//

import Combine
import SwiftUI

struct IslandFocusTabView: View {
    @Binding var focusPandoraMinutes: Int
    @Binding var focusPandoraRemainingSec: Int
    @Binding var focusPandoraIsRunning: Bool
    @Binding var focusPandoraPulse: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Focus")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .tracking(0.45)
                Text(focusPandoraIsRunning ? "COUNTING DOWN" : "READY")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(focusPandoraIsRunning ? Color.white.opacity(0.58) : PandoraChrome.muted)
                    .tracking(0.5)
                Spacer(minLength: 0)
                Text("\(focusPandoraMinutes)m")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.055)))
            }

            HStack(alignment: .center, spacing: 12) {
                focusPandoraProgressMark

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text("Pandora")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(PandoraChrome.muted)
                            .tracking(0.4)
                        Circle()
                            .fill(focusPandoraIsRunning ? Color.white.opacity(0.72) : PandoraChrome.dim)
                            .frame(width: 4, height: 4)
                            .scaleEffect(focusPandoraIsRunning && focusPandoraPulse ? 1.8 : 1)
                            .opacity(focusPandoraIsRunning && focusPandoraPulse ? 0.45 : 1)
                    }

                    Text(focusPandoraTimeString)
                        .font(.system(size: 25, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(
                            focusPandoraRemainingSec == 0
                                ? PandoraChrome.dim
                                : PandoraChrome.primary
                        )
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                focusPandoraControlButton(
                    icon: "arrow.counterclockwise",
                    size: 12,
                    label: "Reset timer",
                    action: resetFocusPandora
                )

                focusPandoraControlButton(
                    icon: focusPandoraIsRunning ? "pause.fill" : "play.fill",
                    size: 17,
                    label: focusPandoraIsRunning ? "Pause" : "Start",
                    isPrimary: true,
                    action: toggleFocusPandora
                )
                .scaleEffect(focusPandoraIsRunning && focusPandoraPulse ? 1.06 : 1)
            }
            .padding(10)
            .background(IslandPanelBackground.notchSubpanel(cornerRadius: 13))

            HStack(spacing: 5) {
                ForEach(focusPandoraPresets, id: \.self) { minutes in
                    focusPandoraPresetChip(minutes: minutes)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(IslandPanelBackground.notchPanel(cornerRadius: 15))
        .animation(
            focusPandoraIsRunning
                ? .easeInOut(duration: 0.75).repeatForever(autoreverses: true)
                : .easeOut(duration: 0.18),
            value: focusPandoraPulse
        )
        .animation(.easeInOut(duration: 0.24), value: focusPandoraRemainingSec)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard focusPandoraIsRunning, focusPandoraRemainingSec > 0 else { return }
            focusPandoraRemainingSec -= 1
            if focusPandoraRemainingSec == 0 { stopFocusPandora() }
        }
    }

    private var focusPandoraPresets: [Int] { [5, 15, 25, 45] }

    private var focusPandoraProgress: CGFloat {
        guard focusPandoraMinutes > 0 else { return 0 }
        let total = CGFloat(focusPandoraMinutes * 60)
        return max(0, min(1, CGFloat(focusPandoraRemainingSec) / total))
    }

    private var focusPandoraProgressMark: some View {
        ZStack {
            Circle()
                .stroke(PandoraChrome.divider, lineWidth: 2)
            Circle()
                .trim(from: 0, to: focusPandoraProgress)
                .stroke(
                    PandoraChrome.primary,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .opacity(focusPandoraRemainingSec == 0 ? 0.25 : 0.9)
            Image(systemName: focusPandoraIsRunning ? "hourglass" : "timer")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(focusPandoraIsRunning ? PandoraChrome.primary : PandoraChrome.muted)
                .symbolEffect(.pulse, options: .repeating, value: focusPandoraIsRunning)
        }
        .frame(width: 34, height: 34)
        .scaleEffect(focusPandoraIsRunning && focusPandoraPulse ? 1.04 : 1)
    }

    private var focusPandoraTimeString: String {
        let m = focusPandoraRemainingSec / 60
        let s = focusPandoraRemainingSec % 60
        return String(format: "%d:%02d", m, s)
    }

    private func focusPandoraPresetChip(minutes: Int) -> some View {
        let selected = focusPandoraMinutes == minutes
        return Button {
            selectFocusPandoraPreset(minutes)
        } label: {
            Text("\(minutes)m")
                .font(.system(size: 9, weight: selected ? .bold : .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(selected ? PandoraChrome.primary : PandoraChrome.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(selected ? Color.white.opacity(0.11) : Color.white.opacity(0.035))
                )
                .overlay(
                    Capsule()
                        .stroke(selected ? Color.white.opacity(0.2) : Color.white.opacity(0.07), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(minutes) minutes")
    }

    private func focusPandoraControlButton(
        icon: String,
        size: CGFloat,
        label: String,
        isPrimary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: isPrimary ? .semibold : .regular))
                .foregroundStyle(isPrimary ? PandoraChrome.primary : PandoraChrome.muted)
                .frame(width: isPrimary ? 34 : 28, height: 30)
                .background(
                    Circle()
                        .fill(isPrimary ? Color.white.opacity(0.1) : Color.white.opacity(0.04))
                )
                .overlay(
                    Circle()
                        .stroke(isPrimary ? Color.white.opacity(0.18) : Color.white.opacity(0.07), lineWidth: 1)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func toggleFocusPandora() {
        if focusPandoraRemainingSec == 0, !focusPandoraIsRunning {
            focusPandoraRemainingSec = focusPandoraMinutes * 60
        }

        withAnimation(.easeInOut(duration: 0.18)) {
            focusPandoraIsRunning.toggle()
            focusPandoraPulse = focusPandoraIsRunning
        }
    }

    private func resetFocusPandora() {
        withAnimation(.easeInOut(duration: 0.18)) {
            focusPandoraIsRunning = false
            focusPandoraPulse = false
            focusPandoraRemainingSec = focusPandoraMinutes * 60
        }
    }

    private func selectFocusPandoraPreset(_ minutes: Int) {
        withAnimation(.easeInOut(duration: 0.18)) {
            focusPandoraIsRunning = false
            focusPandoraPulse = false
            focusPandoraMinutes = minutes
            focusPandoraRemainingSec = minutes * 60
        }
    }

    private func stopFocusPandora() {
        withAnimation(.easeOut(duration: 0.18)) {
            focusPandoraIsRunning = false
            focusPandoraPulse = false
        }
    }
}

#Preview("Focus") {
    @Previewable @State var minutes = 25
    @Previewable @State var remaining = 18 * 60 + 32
    @Previewable @State var running = true
    @Previewable @State var pulse = true
    IslandFocusTabView(
        focusPandoraMinutes: $minutes,
        focusPandoraRemainingSec: $remaining,
        focusPandoraIsRunning: $running,
        focusPandoraPulse: $pulse
    )
    .frame(width: 400, alignment: .leading)
    .padding(16)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
