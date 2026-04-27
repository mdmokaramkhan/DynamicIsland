//
//  NowPlayingSlider.swift
//  DynamicIsland
//
//  boringNotch CustomSlider / MusicSliderView
//

import SwiftUI

/// Real-time scrubbing progress bar.  Tinted by the album art's average colour.
struct NowPlayingSlider: View {
    let duration: TimeInterval
    let currentDate: Date
    let timestampDate: Date
    let elapsedTime: TimeInterval
    let playbackRate: Double
    let isPlaying: Bool
    var tintColor: Color = .white
    /// When set (e.g. system Now Playing), elapsed does not extrapolate beyond this interval without a new snapshot.
    var maxExtrapolationInterval: TimeInterval? = nil
    let onSeek: (TimeInterval) -> Void

    @State private var dragValue: Double = 0
    @State private var isDragging = false
    @State private var lastDragged: Date = .distantPast

    private var currentPosition: Double {
        guard !isDragging else { return dragValue }
        guard timestampDate.timeIntervalSince(lastDragged) > -1 else { return dragValue }
        guard isPlaying else { return min(elapsedTime, duration) }
        var delta = currentDate.timeIntervalSince(timestampDate)
        if let cap = maxExtrapolationInterval {
            delta = min(delta, cap)
        }
        return min(max(0, elapsedTime + delta * playbackRate), duration)
    }

    var body: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                let width = geo.size.width
                let progress = duration > 0 ? currentPosition / duration : 0
                let filled = min(max(progress, 0), 1) * width
                let barH = CGFloat(isDragging ? 6 : 3)

                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: barH)
                    Rectangle()
                        .fill(tintColor.opacity(0.90))
                        .frame(width: max(barH, filled), height: barH)
                }
                .cornerRadius(barH / 2)
                .frame(height: 10)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                isDragging = true
                            }
                            dragValue = min(max(0, Double(g.location.x / width) * duration), duration)
                        }
                        .onEnded { _ in
                            onSeek(dragValue)
                            isDragging = false
                            lastDragged = Date()
                        }
                )
                .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isDragging)
            }
            .frame(height: 10)

            HStack {
                Text(timeString(currentPosition))
                Spacer()
                Text(timeString(duration))
            }
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(tintColor.opacity(0.5))
        }
    }

    private func timeString(_ s: TimeInterval) -> String {
        guard s.isFinite, s >= 0 else { return "0:00" }
        let total = Int(s)
        let h = total / 3600
        let m = (total % 3600) / 60
        let sec = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%d:%02d", m, sec)
    }
}

#Preview {
    NowPlayingSlider(
        duration: 240,
        currentDate: Date(),
        timestampDate: Date(),
        elapsedTime: 90,
        playbackRate: 1,
        isPlaying: false,
        tintColor: Color.cyan.opacity(0.9)
    ) { _ in }
    .frame(width: 300)
    .padding(16)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
