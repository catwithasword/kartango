import SwiftUI

struct StatsView: View {
    let deckCount: Int
    let totalCardCount: Int
    let queueState: QueueState
    let onRebuildTodayQueue: () -> Void
    let onSimulateTomorrowQueue: () -> Void

    @AppStorage("newCardsPerDay", store: UserDefaults(suiteName: AppGroup.identifier))
    private var newCardsPerDay = 10

    @AppStorage("reviewCardsPerDay", store: UserDefaults(suiteName: AppGroup.identifier))
    private var reviewCardsPerDay = 10

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brightBeige
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        statTile(title: "Decks", value: "\(deckCount)")
                        statTile(title: "Cards", value: "\(totalCardCount)")
                        debugTile
                    }
                    .padding(24)
                }
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

    private var debugTile: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("QUEUE DEBUG")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            debugRow(title: "Queue date", value: queueState.queueDate.isEmpty ? "none" : queueState.queueDate)
            debugRow(title: "Current queue", value: "\(queueState.cards.count)")
            debugRow(title: "Remaining review", value: "\(remainingReviewCount)")
            debugRow(title: "Remaining new", value: "\(remainingNewCount)")
            debugRow(title: "Reviewed pool", value: "\(queueState.reviewedCardIDs.count)")
            debugRow(title: "Again counts", value: "\(queueState.againCounts.count)")
            debugRow(title: "Completed today", value: "\(queueState.completedCardIDs.count)")
            debugRow(title: "Daily new limit", value: "\(newCardsPerDay)")
            debugRow(title: "Daily review limit", value: "\(reviewCardsPerDay)")

            Button(action: onRebuildTodayQueue) {
                Text("Rebuild Today's Queue")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.deckAccent, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)

            Button(action: onSimulateTomorrowQueue) {
                Text("Simulate Tomorrow Queue")
                    .font(.headline)
                    .foregroundStyle(Color.deckAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.deckAccent, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(Color.deckCard, in: RoundedRectangle(cornerRadius: 24))
    }

    private var remainingReviewCount: Int {
        let reviewedCardIDs = Set(queueState.reviewedCardIDs)
        return queueState.cards.filter { reviewedCardIDs.contains($0.id) }.count
    }

    private var remainingNewCount: Int {
        let reviewedCardIDs = Set(queueState.reviewedCardIDs)
        return queueState.cards.filter { !reviewedCardIDs.contains($0.id) }.count
    }

    private func debugRow(title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.black.opacity(0.8))

            Spacer(minLength: 12)

            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(Color.deckAccent)
        }
    }
}
