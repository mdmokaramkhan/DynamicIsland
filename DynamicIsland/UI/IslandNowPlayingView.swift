//
//  IslandNowPlayingView.swift
//  DynamicIsland
//
//  Now Playing tab — boringNotch-style layout.
//

import SwiftUI

struct IslandNowPlayingView: View {
    @ObservedObject var musicManager: MusicManager
    let musicControlSlots: [MusicControlButton]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if musicManager.songTitle.isEmpty {
                nowPlayingEmptyPlayerCard
            } else {
                nowPlayingPlayerCard
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(IslandPanelBackground.notchPanel(cornerRadius: 15))
    }

    // MARK: - Player card

    private var nowPlayingPlayerCard: some View {
        HStack(alignment: .top, spacing: 10) {
            nowPlayingAlbumArtView
            nowPlayingControlsView
        }
    }

    private var nowPlayingAlbumArtView: some View {
        let tint = Color(nsColor: musicManager.avgColor)
        return ZStack(alignment: .bottomTrailing) {
            Image(nsImage: musicManager.albumArt)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 68, height: 68)
                .blur(radius: 18)
                .opacity(musicManager.isPlaying ? 0.65 : 0.25)
                .scaleEffect(1.4)
                .rotationEffect(.degrees(92))
                .allowsHitTesting(false)

            Button { musicManager.openMusicApp() } label: {
                Image(nsImage: musicManager.albumArt)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(tint.opacity(0.3), lineWidth: 1)
                    )
                    .frame(width: 68, height: 68)
                    .overlay {
                        if !musicManager.isPlaying {
                            RoundedRectangle(cornerRadius: 11)
                                .fill(Color.black.opacity(0.55))
                        }
                    }
            }
            .buttonStyle(.plain)
            .scaleEffect(musicManager.isPlaying ? 1 : 0.87)
            .animation(.spring(response: 0.38, dampingFraction: 0.72), value: musicManager.isPlaying)

            if let bid = musicManager.bundleIdentifier, !bid.isEmpty {
                AppIcon(for: bid)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
                    .offset(x: 8, y: 8)
                    .id(bid)
            }
        }
        .frame(width: 76, height: 76)
    }

    private var nowPlayingControlsView: some View {
        let tint = Color(nsColor: musicManager.avgColor)
        let displayArtist = musicManager.artistName.isEmpty
            ? musicManager.album
            : musicManager.artistName

        return VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .center, spacing: 6) {
                GeometryReader { geo in
                    VStack(alignment: .leading, spacing: 1) {
                        MarqueeText(
                            musicManager.songTitle,
                            font: .system(size: 13, weight: .bold, design: .rounded),
                            nsFont: .headline,
                            textColor: .white,
                            minDuration: 3.5,
                            frameWidth: geo.size.width
                        )
                        MarqueeText(
                            displayArtist,
                            font: .system(size: 10, weight: .medium),
                            nsFont: .subheadline,
                            textColor: tint.opacity(0.85),
                            minDuration: 3.5,
                            frameWidth: geo.size.width
                        )
                    }
                }
                .frame(height: 36)

                HStack(spacing: 4) {
                    if musicManager.isPlaying {
                        AudioSpectrumView(isPlaying: .constant(true))
                            .frame(width: 16, height: 12)
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 5, height: 5)
                    }
                    Text(musicManager.isPlaying ? "Live" : "Paused")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.055)))
                .overlay(Capsule().stroke(Color.white.opacity(0.09), lineWidth: 1))
                .fixedSize()
            }
            .padding(.bottom, 2)

            TimelineView(.animation(minimumInterval: musicManager.playbackRate > 0 ? 0.1 : nil)) { tl in
                NowPlayingSlider(
                    duration: musicManager.songDuration,
                    currentDate: tl.date,
                    timestampDate: musicManager.timestampDate,
                    elapsedTime: musicManager.elapsedTime,
                    playbackRate: musicManager.playbackRate,
                    isPlaying: musicManager.isPlaying,
                    tintColor: tint,
                    maxExtrapolationInterval: musicManager.isControlCenterSource ? 1.05 : nil
                ) { musicManager.seek(to: $0) }
            }

            nowPlayingSlotToolbar
        }
    }

    // MARK: - Slot toolbar

    private var nowPlayingSlotToolbar: some View {
        let tint = Color(nsColor: musicManager.avgColor)
        return HStack(spacing: 2) {
            ForEach(Array(musicControlSlots.enumerated()), id: \.offset) { _, slot in
                nowPlayingSlotButton(slot, tint: tint)
            }

            Spacer(minLength: 0)

            if !musicManager.sourceLabel.isEmpty {
                Text(musicManager.sourceLabel.uppercased())
                    .font(.system(size: 7, weight: .bold, design: .rounded))
                    .foregroundStyle(tint.opacity(0.6))
                    .tracking(0.5)
            }
        }
        .padding(.top, 1)
    }

    @ViewBuilder
    private func nowPlayingSlotButton(_ slot: MusicControlButton, tint: Color) -> some View {
        switch slot {
        case .none:
            Color.clear
                .frame(width: 28, height: 28)
        case .shuffle:
            MusicHoverButton(icon: slot.iconName, active: musicManager.isShuffled, tint: tint) {
                musicManager.toggleShuffle()
            }
        case .previous:
            MusicHoverButton(icon: slot.iconName) {
                musicManager.previousTrack()
            }
        case .playPause:
            MusicHoverButton(
                icon: musicManager.isPlaying ? "pause.fill" : "play.fill",
                size: .large
            ) {
                musicManager.playPause()
            }
        case .next:
            MusicHoverButton(icon: slot.iconName) {
                musicManager.nextTrack()
            }
        case .repeatMode:
            MusicHoverButton(
                icon: musicManager.repeatMode == .one ? "repeat.1" : slot.iconName,
                active: musicManager.repeatMode != .off,
                tint: tint
            ) {
                musicManager.toggleRepeat()
            }
        case .goBackward:
            MusicHoverButton(icon: slot.iconName) {
                musicManager.goBackward15()
            }
        case .goForward:
            MusicHoverButton(icon: slot.iconName) {
                musicManager.goForward15()
            }
        case .favorite:
            MusicHoverButton(
                icon: musicManager.isFavoriteTrack ? "heart.fill" : slot.iconName,
                active: musicManager.isFavoriteTrack,
                tint: .red
            ) {
                musicManager.toggleFavorite()
            }
        case .volume:
            MusicHoverButton(icon: slot.iconName, active: false, tint: tint) {
                musicManager.openMusicApp()
            }
        }
    }

    // MARK: - Empty state

    private var nowPlayingEmptyPlayerCard: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Image(nsImage: musicManager.albumArt)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 68, height: 68)
                    .blur(radius: 18)
                    .opacity(0.18)
                    .scaleEffect(1.35)
                    .rotationEffect(.degrees(92))
                    .allowsHitTesting(false)

                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.white.opacity(0.045))
                    .frame(width: 68, height: 68)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                Image(systemName: "music.note.list")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.26))
            }
            .frame(width: 76, height: 76)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .center, spacing: 6) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Not Playing")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.82))
                            .lineLimit(1)
                        Text("Start media from any app")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.34))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.white.opacity(0.24))
                            .frame(width: 5, height: 5)
                        Text("Idle")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.42))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.045)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.07), lineWidth: 1))
                    .fixedSize()
                }
                .padding(.bottom, 2)

                NowPlayingSlider(
                    duration: 0,
                    currentDate: Date(),
                    timestampDate: Date(),
                    elapsedTime: 0,
                    playbackRate: 0,
                    isPlaying: false,
                    tintColor: Color.white.opacity(0.28)
                ) { _ in }
                .allowsHitTesting(false)

                HStack(spacing: 2) {
                    ForEach(Array(musicControlSlots.enumerated()), id: \.offset) { _, slot in
                        nowPlayingDisabledSlotButton(slot)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 1)
                .opacity(0.42)
            }
        }
    }

    @ViewBuilder
    private func nowPlayingDisabledSlotButton(_ slot: MusicControlButton) -> some View {
        switch slot {
        case .none:
            Color.clear
                .frame(width: 28, height: 28)
        case .playPause:
            MusicHoverButton(icon: "play.fill", size: .large) {}
                .allowsHitTesting(false)
        case .repeatMode:
            MusicHoverButton(icon: "repeat") {}
                .allowsHitTesting(false)
        case .favorite:
            MusicHoverButton(icon: "heart") {}
                .allowsHitTesting(false)
        default:
            MusicHoverButton(icon: slot.iconName) {}
                .allowsHitTesting(false)
        }
    }
}

#Preview("Now playing") {
    IslandNowPlayingView(
        musicManager: MusicManager.shared,
        musicControlSlots: MusicControlButton.defaultLayout
    )
    .frame(width: 400, alignment: .leading)
    .padding(16)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
