import SwiftUI

struct DonutChart: View {
    let progress: Double
    let centerValue: String
    let centerLabel: String
    let secondaryLabel: String

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let lineWidth = size * 0.18

            ZStack {
                // Background ring
                Circle()
                    .trim(from: 0, to: 1)
                    .stroke(
                        Color.deckAccent.opacity(0.15),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )

                // Progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.deckAccent,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.8), value: progress)

                // Center text
                VStack(spacing: 4) {
                    Text(centerValue)
                        .font(.system(size: size * 0.2, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.deckAccent)

                    Text(centerLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(secondaryLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity)
        }
    }
}
