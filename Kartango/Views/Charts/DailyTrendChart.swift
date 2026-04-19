import SwiftUI

struct DailyTrendChart: View {
    let data: [Double]

    var body: some View {
        GeometryReader { geo in
            let maxY = (data.max() ?? 1) * 1.2
            let minY = 0.0
            let range = maxY - minY
            let stepX = geo.size.width / CGFloat(max(data.count - 1, 1))

            ZStack(alignment: .bottomLeading) {
                // Grid lines
                VStack(spacing: 0) {
                    ForEach(0..<4) { i in
                        Spacer()
                        if i < 3 {
                            Divider()
                                .background(Color.black.opacity(0.06))
                        }
                    }
                }

                // Area fill
                Path { path in
                    guard !data.isEmpty else { return }
                    let points = data.enumerated().map { index, value in
                        CGPoint(
                            x: CGFloat(index) * stepX,
                            y: geo.size.height - CGFloat((value - minY) / range) * geo.size.height
                        )
                    }
                    path.move(to: CGPoint(x: points[0].x, y: geo.size.height))
                    for point in points {
                        path.addLine(to: point)
                    }
                    path.addLine(to: CGPoint(x: points.last!.x, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [Color.deckAccent.opacity(0.25), Color.deckAccent.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Line
                Path { path in
                    guard !data.isEmpty else { return }
                    let points = data.enumerated().map { index, value in
                        CGPoint(
                            x: CGFloat(index) * stepX,
                            y: geo.size.height - CGFloat((value - minY) / range) * geo.size.height
                        )
                    }
                    path.move(to: points[0])
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(Color.deckAccent, lineWidth: 2)

                // Dots
                ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                    let x = CGFloat(index) * stepX
                    let y = geo.size.height - CGFloat((value - minY) / range) * geo.size.height
                    Circle()
                        .fill(Color.deckAccent)
                        .frame(width: 6, height: 6)
                        .position(x: x, y: y)
                }

                // Y-axis labels
                VStack {
                    Text("\(Int(maxY))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int((maxY + minY) / 2))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("0")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .offset(x: -20)
            }
        }
    }
}
