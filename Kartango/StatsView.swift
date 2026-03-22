import SwiftUI

struct StatsView: View {
    let deckCount: Int
    let totalCardCount: Int

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brightBeige
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    statTile(title: "Decks", value: "\(deckCount)")
                    statTile(title: "Cards", value: "\(totalCardCount)")
                }
                .padding(24)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 140)
                }
            }
            .navigationTitle("Stats")
        }
    }

    private func statTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(Color.deckAccent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(Color.deckCard, in: RoundedRectangle(cornerRadius: 24))
    }
}
