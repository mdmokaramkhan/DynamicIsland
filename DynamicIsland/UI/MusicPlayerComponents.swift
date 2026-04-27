//
//  MusicPlayerComponents.swift
//  DynamicIsland
//
//  Shared components used by the music player view.
//  Ported from boringNotch:
//    • MarqueeText            (MarqueeTextView.swift)
//    • AudioSpectrumView      (MusicVisualizer.swift)
//    • NSImage.averageColor   (NSImage+Extensions.swift)
//    • AppIconAsNSImage       (AppIcons.swift)
//    • MusicHoverButton       (HoverButton.swift)
//

import AppKit
import Cocoa
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UniformTypeIdentifiers

// MARK: - MarqueeText (boringNotch MarqueeTextView.swift)

struct MarqueeText: View {
    let text: String
    let font:            Font
    let nsFont:          NSFont.TextStyle
    let textColor:       Color
    let backgroundColor: Color
    let minDuration:     Double
    let frameWidth:      CGFloat

    @State private var animate    = false
    @State private var textSize: CGSize = .zero
    @State private var offset: CGFloat  = 0

    init(
        _ text: String,
        font: Font               = .body,
        nsFont: NSFont.TextStyle = .body,
        textColor: Color         = .primary,
        backgroundColor: Color   = .clear,
        minDuration: Double      = 1.0,
        frameWidth: CGFloat      = 200
    ) {
        self.text            = text
        self.font            = font
        self.nsFont          = nsFont
        self.textColor       = textColor
        self.backgroundColor = backgroundColor
        self.minDuration     = minDuration
        self.frameWidth      = frameWidth
    }

    private var needsScrolling: Bool { textSize.width > frameWidth - 20 }

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .leading) {
                HStack(spacing: 20) {
                    Text(text)
                    Text(text)
                        .opacity(needsScrolling ? 1 : 0)
                }
                .id(text)
                .font(font)
                .foregroundColor(textColor)
                .fixedSize(horizontal: true, vertical: false)
                .offset(x: animate ? offset : 0)
                .animation(
                    animate
                        ? .linear(duration: Double(textSize.width / 30))
                            .delay(minDuration)
                            .repeatForever(autoreverses: false)
                        : .none,
                    value: animate
                )
                .background(backgroundColor)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: MarqueeSizeKey.self,
                            value: geo.size
                        )
                    }
                )
                .onPreferenceChange(MarqueeSizeKey.self) { size in
                    self.textSize = CGSize(
                        width: size.width / 2,
                        height: NSFont.preferredFont(forTextStyle: nsFont).pointSize
                    )
                    self.animate = false
                    self.offset  = 0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        if needsScrolling {
                            self.animate = true
                            self.offset  = -(textSize.width + 10)
                        }
                    }
                }
            }
            .frame(width: frameWidth, alignment: .leading)
            .clipped()
        }
        .frame(height: textSize.height * 1.3)
        .onChange(of: text) { _, _ in
            animate = false
            offset  = 0
        }
    }
}

private struct MarqueeSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// MARK: - AudioSpectrumView (boringNotch MusicVisualizer.swift)

/// Visual layout (compact bars, high count) — use `AudioSpectrumView.contentSize` in SwiftUI for matching frames.
enum AudioSpectrumLayout {
    static let barCount = 8
    static let barWidth: CGFloat = 0.75
    static let interBarSpacing: CGFloat = 0.45
    static let height: CGFloat = 8.5
    static var contentSize: CGSize {
        let w = CGFloat(barCount) * barWidth + CGFloat(max(0, barCount - 1)) * interBarSpacing
        return CGSize(width: w, height: height)
    }
}

/// Slim multi-bar equaliser. Motions are ease-in-out (no `autoreverses` twitch); gentler on resume after view swap.
class AudioSpectrumNSView: NSView {
    private var barLayers: [CAShapeLayer] = []
    private var barScales: [CGFloat] = []
    private var animationTimer: Timer?
    private var gentleStartTask: DispatchWorkItem?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupBars()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupBars()
    }

    private func setupBars() {
        let barWidth = AudioSpectrumLayout.barWidth
        let barCount = AudioSpectrumLayout.barCount
        let spacing = AudioSpectrumLayout.interBarSpacing
        let totalHeight = AudioSpectrumLayout.height
        let totalWidth = AudioSpectrumLayout.contentSize.width
        frame.size = CGSize(width: totalWidth, height: totalHeight)

        for i in 0 ..< barCount {
            let x = CGFloat(i) * (barWidth + spacing)
            let layer = CAShapeLayer()
            layer.frame = CGRect(x: x, y: 0, width: barWidth, height: totalHeight)
            layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            layer.position = CGPoint(x: x + barWidth / 2, y: totalHeight / 2)
            layer.fillColor = NSColor.white.cgColor
            layer.backgroundColor = NSColor.white.cgColor
            layer.masksToBounds = true
            let path = NSBezierPath(
                roundedRect: CGRect(x: 0, y: 0, width: barWidth, height: totalHeight),
                xRadius: barWidth / 2, yRadius: barWidth / 2
            )
            layer.path = path.cgPath
            barLayers.append(layer)
            barScales.append(0.38)
            self.layer?.addSublayer(layer)
        }
    }

    private func startAnimating() {
        guard animationTimer == nil else { return }
        gentleStartTask?.cancel()
        // First draw after a frame so fade-in from chip swap doesn’t look like a pop.
        let first = DispatchWorkItem { [weak self] in
            self?.updateBars(soft: true)
        }
        gentleStartTask = first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: first)

        let interval: TimeInterval = 0.52
        let t = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateBars(soft: false)
        }
        RunLoop.main.add(t, forMode: .common)
        animationTimer = t
    }

    private func stopAnimating() {
        gentleStartTask?.cancel()
        gentleStartTask = nil
        animationTimer?.invalidate()
        animationTimer = nil
        resetBars()
    }

    private func updateBars(soft: Bool) {
        let minScale: CGFloat = soft ? 0.45 : 0.4
        let maxScale: CGFloat = soft ? 0.82 : 0.9
        let duration: CFTimeInterval = soft ? 0.72 : 0.58
        let ease = CAMediaTimingFunction(name: .easeInEaseOut)

        for (i, layer) in barLayers.enumerated() {
            let current = barScales[i]
            let target = CGFloat.random(in: minScale ... maxScale)
            barScales[i] = target
            layer.removeAnimation(forKey: "scaleY")
            let anim = CABasicAnimation(keyPath: "transform.scale.y")
            anim.fromValue = current
            anim.toValue = target
            anim.duration = duration
            anim.timingFunction = ease
            anim.fillMode = .forwards
            anim.isRemovedOnCompletion = false
            if #available(macOS 13.0, *) {
                anim.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
            }
            layer.add(anim, forKey: "scaleY")
        }
    }

    private func resetBars() {
        for (i, layer) in barLayers.enumerated() {
            layer.removeAllAnimations()
            layer.transform = CATransform3DMakeScale(1, 0.36, 1)
            barScales[i] = 0.36
        }
    }

    func setPlaying(_ playing: Bool) {
        if playing { startAnimating() } else { stopAnimating() }
    }
}

struct AudioSpectrumView: NSViewRepresentable {
    @Binding var isPlaying: Bool

    /// Use this in `.frame` / masks for layout that matches the AppKit subview.
    static var contentSize: CGSize { AudioSpectrumLayout.contentSize }

    func makeNSView(context: Context) -> AudioSpectrumNSView {
        let v = AudioSpectrumNSView()
        v.setPlaying(isPlaying)
        return v
    }

    func updateNSView(_ nsView: AudioSpectrumNSView, context: Context) {
        nsView.setPlaying(isPlaying)
    }
}

// MARK: - NSImage.averageColor (boringNotch NSImage+Extensions.swift)

extension NSImage {
    /// Calculates the average colour of the image on a background thread and
    /// calls the completion handler on the main thread.
    func averageColor(completion: @escaping (NSColor?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let cgImg = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let w = cgImg.width, h = cgImg.height
            let total = w * h
            guard let ctx = CGContext(
                data: nil, width: w, height: h,
                bitsPerComponent: 8, bytesPerRow: w * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            ctx.draw(cgImg, in: CGRect(x: 0, y: 0, width: w, height: h))
            guard let data = ctx.data else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let ptr = data.bindMemory(to: UInt32.self, capacity: total)
            var r: UInt64 = 0, g: UInt64 = 0, b: UInt64 = 0
            for i in 0 ..< total {
                let px = ptr[i]
                r += UInt64(px & 0xFF)
                g += UInt64((px >> 8) & 0xFF)
                b += UInt64((px >> 16) & 0xFF)
            }
            let n = CGFloat(total)
            let ar = CGFloat(r) / n / 255
            let ag = CGFloat(g) / n / 255
            let ab = CGFloat(b) / n / 255
            let minBrightness: CGFloat = 0.5
            let isNearBlack = ar < 0.03 && ag < 0.03 && ab < 0.03
            let finalColor: NSColor
            if isNearBlack {
                finalColor = NSColor(white: minBrightness, alpha: 1)
            } else {
                var color = NSColor(red: ar, green: ag, blue: ab, alpha: 1)
                var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
                color.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha)
                if bri < minBrightness {
                    color = NSColor(
                        hue: hue,
                        saturation: sat * (bri / minBrightness),
                        brightness: minBrightness, alpha: alpha
                    )
                }
                finalColor = color
            }
            DispatchQueue.main.async { completion(finalColor) }
        }
    }
}

extension Color {
    func ensureMinimumBrightness(factor: CGFloat) -> Color {
        guard factor >= 0, factor <= 1 else { return self }
        let ns = NSColor(self)
        guard let rgb = ns.usingColorSpace(.sRGB) else { return self }
        var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0, a: CGFloat = 0
        rgb.getRed(&r, green: &g, blue: &bl, alpha: &a)
        let perceived = 0.2126 * r + 0.7152 * g + 0.0722 * bl
        guard perceived > 0 else { return self }
        let scale = factor / perceived
        return Color(
            red:     Double(min(r  * scale, 1)),
            green:   Double(min(g  * scale, 1)),
            blue:    Double(min(bl * scale, 1)),
            opacity: Double(a)
        )
    }
}

// MARK: - AppIconAsNSImage (boringNotch AppIcons.swift)

func AppIconAsNSImage(for bundleID: String) -> NSImage? {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
        return nil
    }
    let icon = NSWorkspace.shared.icon(forFile: url.path)
    icon.size = NSSize(width: 256, height: 256)
    return icon
}

func AppIcon(for bundleID: String) -> Image {
    if let img = AppIconAsNSImage(for: bundleID) {
        return Image(nsImage: img)
    }
    return Image(nsImage: NSWorkspace.shared.icon(for: .applicationBundle))
}

// MARK: - MusicControlButton (boringNotch MusicControlButton.swift)

enum MusicControlButton: String, CaseIterable, Identifiable, Codable, Equatable {
    case shuffle
    case previous
    case playPause
    case next
    case repeatMode
    case volume
    case favorite
    case goBackward
    case goForward
    case none

    var id: String { rawValue }

    static let defaultLayout: [MusicControlButton] = [
        .none,
        .previous,
        .playPause,
        .next,
        .none
    ]

    static let pickerOptions: [MusicControlButton] = [
        .shuffle,
        .previous,
        .playPause,
        .next,
        .repeatMode,
        .favorite,
        .volume,
        .goBackward,
        .goForward
    ]

    var label: String {
        switch self {
        case .shuffle: return "Shuffle"
        case .previous: return "Previous"
        case .playPause: return "Play/Pause"
        case .next: return "Next"
        case .repeatMode: return "Repeat"
        case .volume: return "Volume"
        case .favorite: return "Favorite"
        case .goBackward: return "Backward 15s"
        case .goForward: return "Forward 15s"
        case .none: return "Empty slot"
        }
    }

    var iconName: String {
        switch self {
        case .shuffle: return "shuffle"
        case .previous: return "backward.fill"
        case .playPause: return "playpause"
        case .next: return "forward.fill"
        case .repeatMode: return "repeat"
        case .volume: return "speaker.wave.2.fill"
        case .favorite: return "heart"
        case .goBackward: return "gobackward.15"
        case .goForward: return "goforward.15"
        case .none: return ""
        }
    }

    var prefersLargeScale: Bool {
        self == .playPause
    }
}

// MARK: - MusicHoverButton (boringNotch HoverButton.swift)

enum MusicHoverButtonSize { case small, medium, large }

struct MusicHoverButton: View {
    var icon:    String
    var size:    MusicHoverButtonSize = .medium
    var active:  Bool = false
    var tint:    Color = .white
    var action:  () -> Void

    @State private var hovered = false

    private var iconSize: CGFloat {
        switch size {
        case .small:  return 12
        case .medium: return 14
        case .large:  return 20
        }
    }
    private var frameSize: CGFloat {
        switch size {
        case .small:  return 22
        case .medium: return 28
        case .large:  return 38
        }
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: size == .large ? .medium : .regular))
                .foregroundColor(active ? tint : (hovered ? .white : .white.opacity(0.7)))
                .frame(width: frameSize, height: frameSize)
                .background(
                    Circle()
                        .fill(hovered
                              ? (active ? tint.opacity(0.25) : Color.white.opacity(0.15))
                              : .clear)
                )
                .scaleEffect(hovered ? 1.08 : 1)
                .animation(.easeOut(duration: 0.12), value: hovered)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

#Preview("Marquee + hover buttons") {
    VStack(alignment: .leading, spacing: 16) {
        MarqueeText(
            "This is a long track title that should scroll in the island",
            font: .system(size: 13, weight: .bold, design: .rounded),
            textColor: .white,
            minDuration: 2,
            frameWidth: 220
        )
        HStack(spacing: 4) {
            MusicHoverButton(icon: "backward.fill", size: .small) {}
            MusicHoverButton(icon: "play.fill", size: .large) {}
            MusicHoverButton(icon: "forward.fill", size: .small) {}
            MusicHoverButton(icon: "shuffle", active: true, tint: .orange) {}
        }
        AudioSpectrumView(isPlaying: .constant(true))
            .frame(width: 32, height: 16)
    }
    .padding(20)
    .frame(width: 320, alignment: .leading)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
