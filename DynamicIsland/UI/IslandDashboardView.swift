//
//  IslandDashboardView.swift
//  DynamicIsland
//
//  Created by Md Mukrram Khan on 27/04/26.
//


//
//  IslandDashboardView.swift
//

import SwiftUI

struct IslandDashboardView: View {

    @ObservedObject var focusTimer: FocusPandoraTimer

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // MARK: - DATE
            Text(currentDate)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))

            // MARK: - BIG TIME
            HStack(alignment: .firstTextBaseline, spacing: 6) {

                Text(mainTime)
                    .font(.system(size: 72, weight: .thin, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                Text(seconds)
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(.white.opacity(0.7))
            }

            // MARK: - SECTION TITLE
            HStack {
                Text("Focus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))

                Spacer()

                Text(sessionLength)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                    .foregroundStyle(.black)
                    .clipShape(Capsule())
            }

            // MARK: - ORANGE PROGRESS CARD
            progressCard

            // MARK: - BOTTOM INFO
            HStack {
                Text("25°C")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(.white.opacity(0.8))

                Spacer()

                HStack(spacing: 12) {
                    Image(systemName: "wifi")
                    Image(systemName: "bolt.horizontal")
                }
                .font(.system(size: 18))
                .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.black)
        )
    }

    // MARK: - PROGRESS CARD

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Text("Start")
                Spacer()
                Text("End")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.black.opacity(0.8))

            ZStack(alignment: .leading) {

                // Dotted line
                HStack(spacing: 3) {
                    ForEach(0..<50) { _ in
                        Rectangle()
                            .fill(Color.black.opacity(0.4))
                            .frame(width: 2, height: 2)
                    }
                }

                // Progress fill
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 200 * focusTimer.progress, height: 3)
            }

            HStack {
                Text("FOCUS")
                Spacer()
                Text("ACTIVE")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.black.opacity(0.7))
        }
        .padding(16)
        .background(Color.orange)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - HELPERS

    private var mainTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }

    private var seconds: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ss"
        return formatter.string(from: Date())
    }

    private var currentDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE dd"
        return formatter.string(from: Date())
    }

    private var sessionLength: String {
        "\(focusTimer.defaultMinutes)M"
    }
}

#Preview {
    IslandDashboardView(focusTimer: .shared)
        .frame(width: 350)
        .background(Color.gray.opacity(0.2))
}