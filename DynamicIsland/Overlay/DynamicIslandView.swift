//
//  DynamicIslandView.swift
//  DynamicIsland
//
//  The black notch-shaped view that lives inside the island panel.
//  Width is mode-specific. Height is:
//    • idle / keystroke  → fixed (compact pill)
//    • hover-expanded    → content-driven (island grows to fit)
//
//  The NotchShape is used as a .background so SwiftUI sizes it to
//  match the content, not the other way around.
//
//  Keystroke strip (288pt): while music is playing, album + equaliser; when a
//  recent keystroke is shown, the row cross-fades to frontmost app + chip.
//  Full Now Playing remains in the hover-expanded tab panel.
//
//  Expanded (hover) interaction: debounced open/close, haptic on open from idle,
//  bouncy open / damped close springs, and shadow — aligned with the boringNotch
//  reference. Idle pill stays 190×30 with no empty spacer above the shape.
//

import SwiftUI

struct DynamicIslandView: View {
    private enum DisplayMode {
        case idle
        case hoverExpanded
        case keystrokeExpanded
    }

    // Collapsed + keystroke — compact sizes
    private let collapsedSize = CGSize(width: 190, height: 30)
    // closed: top = 6, bottom = 14 (boringNotch / cornerRadiusInsets)
    private let collapsedTopRadius: CGFloat = 6
    private let collapsedBottomRadius: CGFloat = 14

    private let keystrokeWidth: CGFloat = 288
    private let keystrokeContentHeight: CGFloat = 20

    // Matches IslandMetrics.panelSize.width and boringNotch openNotchSize
    private let hoverExpandedWidth: CGFloat = 640

    // Safe inset for tab content; keeps UI off the curved notch border
    private let expandedContentInset = EdgeInsets(top: 8, leading: 30, bottom: 24, trailing: 30)

    // opened: top = 19, bottom = 24
    private let expandedTopRadius: CGFloat = 19
    private let expandedBottomRadius: CGFloat = 24

    // Keystroke strip — capsule-like, tuned for a short height
    private let keystrokePillTopRadius: CGFloat = 5
    private let keystrokePillBottomRadius: CGFloat = 18

    private var openAnimation: Animation {
        if #available(macOS 14.0, *) {
            return .spring(.bouncy(duration: 0.4))
        }
        return .timingCurve(0.16, 1, 0.3, 1, duration: 0.7)
    }
    private let closeAnimation = Animation.spring(
        response: 0.45, dampingFraction: 1.0, blendDuration: 0
    )
    /// Fade in / out the compact strip (music + keystroke) so the player never “pops” with scale.
    private let stripContentFade = Animation.easeInOut(duration: 0.32)

    private let inputExpansionDuration: TimeInterval = 1.5
    private let hoverOpenDelay: UInt64 = 150_000_000
    private let hoverCloseDelay: UInt64 = 100_000_000

    @ObservedObject var keyboardMonitor: GlobalKeystrokeMonitor
    @ObservedObject var keystrokeStore: KeystrokePanelStore
    @ObservedObject var musicManager: MusicManager
    @ObservedObject private var focusTimer = FocusPandoraTimer.shared
    let hitState: IslandHitState
    /// Presents the standard settings window (not island content).
    var onOpenSettings: () -> Void = {}

    @AppStorage(AppSettings.Key.selectedTab) private var selectedTabRaw: String = IslandTab.media.rawValue
    @AppStorage(AppSettings.Key.appearanceShadow) private var dropShadow: Bool = true

    @State private var isHovering = false
    @State private var isExpandedByInput = false
    @State private var isComposingTask = false
    @State private var displayMode: DisplayMode = .idle
    @State private var collapseWorkItem: DispatchWorkItem?
    @State private var keyNoteExpiryWorkItem: DispatchWorkItem?
    /// Bumps when the keystroke “note” TTL ends so `visibleKeystrokeToken` is re-evaluated (time alone does not redraw).
    @State private var keyNoteDisplayTick: UInt = 0
    @State private var hoverTask: Task<Void, Never>?
    @State private var hapticTrigger: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            islandPill
                .onHover { handleHover($0) }
                .onChange(of: keystrokeStore.lastKeystrokeToken) { _ in
                    guard keystrokeStore.lastKeystrokeToken != nil else { return }
                    triggerInputExpansion()
                }
                .onDisappear {
                    hoverTask?.cancel()
                    collapseWorkItem?.cancel()
                    collapseWorkItem = nil
                    keyNoteExpiryWorkItem?.cancel()
                    keyNoteExpiryWorkItem = nil
                }
                .sensoryFeedback(.alignment, trigger: hapticTrigger)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            recalculateDisplayMode()
            scheduleKeyNoteExpiryRefreshIfNeeded()
        }
        .onChange(of: keystrokeStore.lastKeystrokeAt) { _, new in
            if new != nil {
                scheduleKeyNoteExpiryRefresh()
            } else {
                keyNoteExpiryWorkItem?.cancel()
                keyNoteExpiryWorkItem = nil
            }
        }
        .onChange(of: musicManager.isPlaying) { _, _ in
            withAnimation(stripContentFade) { recalculateDisplayMode() }
        }
        .onChange(of: focusTimer.isRunning) { _, _ in
            withAnimation(stripContentFade) { recalculateDisplayMode() }
        }
        .onChange(of: focusTimer.remainingSec) { _, _ in
            guard displayMode != .hoverExpanded else { return }
            withAnimation(stripContentFade) { recalculateDisplayMode() }
        }
        .onChange(of: isComposingTask) { _, _ in
            withAnimation(isComposingTask ? openAnimation : closeAnimation) {
                recalculateDisplayMode()
            }
        }
    }

    // MARK: - Island pill

    @ViewBuilder
    private var islandPill: some View {
        VStack(spacing: 0) {
            if displayMode == .keystrokeExpanded {
                islandModeContent
                    .transition(.opacity)
            } else if displayMode == .hoverExpanded {
                islandModeContent
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.97, anchor: .top)),
                            removal: .opacity
                        )
                    )
            }
        }
        .frame(
            width: currentWidth,
            height: displayMode == .idle ? collapsedSize.height : nil
        )
        .background(
            ZStack {
                if shouldDrawAmbientShadow {
                    NotchShape(topRadius: currentTopRadius, bottomRadius: currentBottomRadius)
                        .fill(Color.black.opacity(0.48))
                        .blur(radius: 14)
                        .offset(y: 7)
                        .padding(.horizontal, -10)
                        .padding(.bottom, -18)
                        .transition(.opacity)
                }

                NotchShape(topRadius: currentTopRadius, bottomRadius: currentBottomRadius)
                    .fill(Color.black)
            }
        )
        .clipShape(
            NotchShape(topRadius: currentTopRadius, bottomRadius: currentBottomRadius)
        )
        // Idle and compact strip share the same ease; hover keeps the bouncy open spring.
        .animation(modeChangeAnimation, value: displayMode)
        .animation(.smooth(duration: 0.32), value: selectedTabRaw)
    }

    private var shouldDrawAmbientShadow: Bool {
        dropShadow && displayMode != .idle
    }

    private var modeChangeAnimation: Animation {
        switch displayMode {
        case .idle, .keystrokeExpanded: stripContentFade
        case .hoverExpanded: openAnimation
        }
    }

    @ViewBuilder
    private var islandModeContent: some View {
        if displayMode == .keystrokeExpanded {
            compactKeystrokeStrip
                .frame(height: keystrokeContentHeight)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        } else if displayMode == .hoverExpanded {
            islandExpandedContent
                .padding(expandedContentInset)
        }
    }

    // MARK: - Expanded content

    @ViewBuilder
    private var islandExpandedContent: some View {
        IslandTabView(
            keyboardMonitor: keyboardMonitor,
            isComposingTask: $isComposingTask,
            onOpenSettings: onOpenSettings
        )
    }

    // MARK: - Compact strip (music + keystroke, animated)

    /// True when a recent key event should show app + note instead of album + music animation.
    private var showKeyNoteInStrip: Bool {
        visibleKeystrokeToken != nil
    }

    /// Drives cross-fade between “music” and “keystroke” row layouts.
    private var compactStripContentSignature: String {
        let tid = visibleKeystrokeToken.map { $0.id.uuidString } ?? ""
        return "\(keyNoteDisplayTick)-\(showKeyNoteInStrip)-\(tid)-\(musicManager.isPlaying)-\(focusTimer.isRunning)-\(focusTimer.phase.rawValue)-\(focusTimer.remainingSec)"
    }

    private var compactKeystrokeStrip: some View {
        let tint = Color(nsColor: musicManager.avgColor)
        let showKey = showKeyNoteInStrip
        return HStack(spacing: 0) {
            if showKey {
                appIconView
            } else if focusTimer.isRunning {
                compactFocusLeading
            } else {
                musicAlbumLeading(tint: tint)
            }
            Spacer(minLength: 8)
            if showKey, let token = visibleKeystrokeToken {
                KeystrokeChipView(token: token)
            } else if focusTimer.isRunning {
                compactFocusTrailing
            } else if musicManager.isPlaying {
                musicPlayingIndicator(tint: tint)
            } else {
                Color.clear.frame(width: 1, height: keystrokeContentHeight)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(stripContentFade, value: compactStripContentSignature)
    }

    private var compactFocusLeading: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: 2)
            Circle()
                .trim(from: 0, to: focusTimer.progress)
                .stroke(Color.white.opacity(0.82), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: focusTimer.phase.symbol)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.76))
        }
        .frame(width: 20, height: 20)
    }

    private var compactFocusTrailing: some View {
        HStack(spacing: 6) {
            Text(focusTimer.compactStatus)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(0.82))
                .lineLimit(1)

            Circle()
                .fill(Color.white.opacity(0.7))
                .frame(width: 4, height: 4)
                .scaleEffect(focusTimer.pulse ? 1.6 : 1)
                .opacity(focusTimer.pulse ? 0.45 : 1)
        }
    }

    private func musicAlbumLeading(tint: Color) -> some View {
        Button { musicManager.openMusicApp() } label: {
            Image(nsImage: musicManager.albumArt)
                .resizable()
                .aspectRatio(1, contentMode: .fill)
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(tint.opacity(0.35), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func musicPlayingIndicator(tint: Color) -> some View {
        let spectrumSize = AudioSpectrumView.contentSize
        // Native layout is many slim bars; mild scale (vs 3.2×) so it eases in softly after the chip.
        return LinearGradient(
            colors: [
                tint.opacity(0.95),
                tint.opacity(0.45),
                Color.white.opacity(0.9),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: 24, height: 24)
        .mask {
            AudioSpectrumView(isPlaying: musicPlayingIndicatorBinding)
                .frame(width: spectrumSize.width, height: spectrumSize.height)
                .scaleEffect(x: 1.85, y: 1.32, anchor: .center)
        }
    }

    private var musicPlayingIndicatorBinding: Binding<Bool> {
        Binding(
            get: { musicManager.isPlaying },
            set: { _ in }
        )
    }

    @ViewBuilder
    private var appIconView: some View {
        if let appIcon = keystrokeStore.frontmostAppIcon {
            Image(nsImage: appIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.8))
                .frame(width: 20, height: 20)
        }
    }

    // MARK: - Mode metrics

    private var currentWidth: CGFloat {
        switch displayMode {
        case .idle:              return collapsedSize.width
        case .hoverExpanded:     return hoverExpandedWidth
        case .keystrokeExpanded: return keystrokeWidth
        }
    }

    private var currentTopRadius: CGFloat {
        switch displayMode {
        case .idle:              return collapsedTopRadius
        case .hoverExpanded:     return expandedTopRadius
        case .keystrokeExpanded: return keystrokePillTopRadius
        }
    }

    private var currentBottomRadius: CGFloat {
        switch displayMode {
        case .idle:              return collapsedBottomRadius
        case .hoverExpanded:     return expandedBottomRadius
        case .keystrokeExpanded: return keystrokePillBottomRadius
        }
    }

    // MARK: - Hover

    private func handleHover(_ hovering: Bool) {
        hoverTask?.cancel()

        if hovering {
            withAnimation(openAnimation) { isHovering = true }

            if displayMode == .idle { hapticTrigger.toggle() }

            guard displayMode == .idle || displayMode == .keystrokeExpanded else { return }
            hoverTask = Task {
                try? await Task.sleep(nanoseconds: hoverOpenDelay)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard self.isHovering,
                          self.displayMode == .idle || self.displayMode == .keystrokeExpanded
                    else { return }
                    withAnimation(self.openAnimation) { self.recalculateDisplayMode() }
                }
            }
        } else {
            hoverTask = Task {
                try? await Task.sleep(nanoseconds: hoverCloseDelay)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(self.closeAnimation) {
                        self.isHovering = false
                        self.recalculateDisplayMode()
                    }
                }
            }
        }
    }

    // MARK: - Keystroke expansion

    private var visibleKeystrokeToken: KeystrokeToken? {
        _ = keyNoteDisplayTick
        guard let token = keystrokeStore.lastKeystrokeToken,
              let lastKeystrokeAt = keystrokeStore.lastKeystrokeAt else {
            return nil
        }
        let age = Date().timeIntervalSince(lastKeystrokeAt)
        return age <= inputExpansionDuration ? token : nil
    }

    /// When the 1.5s “note” window ends, the view must refresh — `Date()`-based checks do not auto-invalidate.
    private func scheduleKeyNoteExpiryRefresh() {
        keyNoteExpiryWorkItem?.cancel()
        guard keystrokeStore.lastKeystrokeAt != nil else { return }
        let w = DispatchWorkItem { [self] in
            withAnimation(stripContentFade) {
                keyNoteDisplayTick &+= 1
                recalculateDisplayMode()
            }
        }
        keyNoteExpiryWorkItem = w
        DispatchQueue.main.asyncAfter(deadline: .now() + inputExpansionDuration, execute: w)
    }

    private func scheduleKeyNoteExpiryRefreshIfNeeded() {
        keyNoteExpiryWorkItem?.cancel()
        guard let t = keystrokeStore.lastKeystrokeAt else { return }
        let age = Date().timeIntervalSince(t)
        if age >= inputExpansionDuration {
            withAnimation(stripContentFade) {
                keyNoteDisplayTick &+= 1
                recalculateDisplayMode()
            }
            return
        }
        let remain = inputExpansionDuration - age
        let w = DispatchWorkItem { [self] in
            withAnimation(stripContentFade) {
                keyNoteDisplayTick &+= 1
                recalculateDisplayMode()
            }
        }
        keyNoteExpiryWorkItem = w
        DispatchQueue.main.asyncAfter(deadline: .now() + remain, execute: w)
    }

    private func triggerInputExpansion() {
        guard displayMode == .idle || displayMode == .keystrokeExpanded else { return }

        withAnimation(stripContentFade) {
            isExpandedByInput = true
            recalculateDisplayMode()
        }

        collapseWorkItem?.cancel()
        let workItem = DispatchWorkItem { [self] in
            withAnimation(stripContentFade) {
                isExpandedByInput = false
                recalculateDisplayMode()
            }
        }
        collapseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + inputExpansionDuration, execute: workItem)
    }

    // MARK: - State

    private func recalculateDisplayMode() {
        if isComposingTask {
            displayMode = .hoverExpanded
        } else if isHovering {
            displayMode = .hoverExpanded
        } else if isExpandedByInput
            || visibleKeystrokeToken != nil
            || focusTimer.isRunning
            || musicManager.isPlaying
        {
            displayMode = .keystrokeExpanded
        } else {
            displayMode = .idle
        }
        hitState.isHoverExpanded = displayMode == .hoverExpanded
        switch displayMode {
        case .idle:
            hitState.compactHitSize = collapsedSize
        case .keystrokeExpanded:
            // Matches compact strip: vertical padding 8+8 plus content height.
            hitState.compactHitSize = CGSize(
                width: keystrokeWidth,
                height: keystrokeContentHeight + 16
            )
        case .hoverExpanded:
            break
        }
    }
}

#Preview {
    DynamicIslandView(
        keyboardMonitor: GlobalKeystrokeMonitor(),
        keystrokeStore: KeystrokePanelStore(),
        musicManager: MusicManager.shared,
        hitState: IslandHitState(),
        onOpenSettings: {}
    )
    .frame(width: 680, height: 400)
    .background(Color.gray.opacity(0.2))
}
