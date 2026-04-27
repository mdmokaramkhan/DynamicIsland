//
//  PermissionOnboardingView.swift
//  DynamicIsland
//
//  Shown once at first launch (or whenever a critical permission is missing).
//  Each row checks the current PermissionManager status and offers an
//  "Allow" button that triggers the real macOS permission dialog.
//

import SwiftUI

// MARK: - Main view

struct PermissionOnboardingView: View {
    @ObservedObject private var mgr = PermissionManager.shared
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Dark background
            Color(nsColor: .windowBackgroundColor)
                .overlay(Color.black.opacity(0.55))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.top, 36)
                    .padding(.bottom, 28)

                permissionRows
                    .padding(.horizontal, 24)

                Spacer(minLength: 24)

                footer
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
        }
        .frame(width: 500, height: 560)
        .preferredColorScheme(.dark)
        .onAppear { mgr.checkAll() }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.22, green: 0.42, blue: 0.88).opacity(0.55),
                                Color.white.opacity(0.07),
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .frame(width: 64, height: 64)
                Image(systemName: "island")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.white)
            }

            Text("Set Up Dynamic Island")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Grant the permissions below to unlock all features.\nYou can always change these in System Settings.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
    }

    // MARK: Permission rows

    private var permissionRows: some View {
        VStack(spacing: 10) {
            PermissionRow(
                icon: "keyboard",
                iconTint: Color(red: 0.3, green: 0.7, blue: 1.0),
                title: "Accessibility",
                description: "Required to capture keystrokes and show them in the island.",
                status: mgr.accessibility,
                actionLabel: "Allow",
                isLoading: false
            ) {
                mgr.requestAccessibility()
            }

            PermissionRow(
                icon: "music.note",
                iconTint: Color(red: 0.98, green: 0.3, blue: 0.35),
                title: "Apple Music",
                description: "Required to display and control now-playing tracks from Apple Music.",
                status: mgr.appleMusicAutomation,
                actionLabel: "Allow",
                isLoading: mgr.isRequesting
            ) {
                Task { await mgr.requestAppleMusicAutomation() }
            }

            PermissionRow(
                icon: "headphones",
                iconTint: Color(red: 0.12, green: 0.87, blue: 0.46),
                title: "Spotify",
                description: "Required to display and control now-playing tracks from Spotify.",
                status: mgr.spotifyAutomation,
                actionLabel: "Allow",
                isLoading: mgr.isRequesting
            ) {
                Task { await mgr.requestSpotifyAutomation() }
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                mgr.markOnboardingComplete()
                onDismiss()
            } label: {
                Text("Skip for Now")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                            .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button {
                mgr.markOnboardingComplete()
                onDismiss()
            } label: {
                HStack(spacing: 6) {
                    Text(mgr.allGranted ? "All Set!" : "Continue")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Image(systemName: mgr.allGranted ? "checkmark" : "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(mgr.allGranted ? Color.mint : Color.white)
                )
            }
            .buttonStyle(.plain)
            .animation(.smooth(duration: 0.25), value: mgr.allGranted)
        }
    }
}

// MARK: - Individual permission row

struct PermissionRow: View {
    let icon: String
    let iconTint: Color
    let title: String
    let description: String
    let status: PermissionStatus
    let actionLabel: String
    let isLoading: Bool
    let onAllow: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Icon badge
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(iconTint.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(iconTint.opacity(0.25), lineWidth: 1)
                    )
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(iconTint)
            }

            // Text
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(description)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Status + action
            VStack(alignment: .trailing, spacing: 6) {
                statusBadge
                if status != .granted {
                    allowButton
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(status == .granted ? 0.04 : 0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            status == .granted
                                ? Color.mint.opacity(0.22)
                                : Color.white.opacity(0.09),
                            lineWidth: 1
                        )
                )
        )
        .animation(.smooth(duration: 0.25), value: status)
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
                .shadow(color: statusColor.opacity(0.6), radius: 3)
            Text(status.label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(statusColor.opacity(0.1)))
    }

    private var statusColor: Color {
        switch status {
        case .granted:       return .mint
        case .denied:        return Color(red: 1, green: 0.27, blue: 0.27)
        case .notDetermined: return .orange
        case .unknown:       return Color.white.opacity(0.4)
        }
    }

    private var allowButton: some View {
        Button {
            onAllow()
        } label: {
            HStack(spacing: 4) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.system(size: 10, weight: .semibold))
                }
                Text(actionLabel)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Color.orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(0.1))
                    .overlay(Capsule().stroke(Color.orange.opacity(0.25), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

#Preview("Onboarding") {
    PermissionOnboardingView(onDismiss: {})
}

#Preview("Permission row") {
    PermissionRow(
        icon: "hand.raised",
        iconTint: .orange,
        title: "Accessibility",
        description: "Needed to show keystrokes in the island",
        status: .notDetermined,
        actionLabel: "Open Settings",
        isLoading: false,
        onAllow: {}
    )
    .padding()
    .frame(width: 480)
    .background(Color(nsColor: .windowBackgroundColor).opacity(0.9))
    .preferredColorScheme(.dark)
}
