import SwiftUI

struct AgainPassBar: View {
    let againPercent: Double

    private var passPercent: Double {
        1.0 - againPercent
    }

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                let againWidth = geo.size.width * againPercent

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.green.opacity(0.3))

                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.red.opacity(0.35))
                        .frame(width: againWidth)
                }
            }
            .frame(height: 28)

            HStack {
                Label {
                    Text("Again")
                        .font(.subheadline.weight(.medium))
                } icon: {
                    Circle()
                        .fill(Color.red.opacity(0.5))
                        .frame(width: 10, height: 10)
                }

                Spacer()

                Text("\(Int(againPercent * 100))%")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.red.opacity(0.7))

                Spacer()

                Text("\(Int(passPercent * 100))%")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.green.opacity(0.8))

                Spacer()

                Label {
                    Text("Pass")
                        .font(.subheadline.weight(.medium))
                } icon: {
                    Circle()
                        .fill(Color.green.opacity(0.5))
                        .frame(width: 10, height: 10)
                }
            }
        }
    }
}
