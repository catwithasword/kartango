import SwiftUI

struct DeckRowView: View {
    let deck: Deck
    let queueState: QueueState

    var body: some View {
        HStack(spacing: 16) {
            Text(deck.name)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.black.opacity(0.85))
                .lineLimit(1)

            Spacer(minLength: 12)

            HStack(spacing: 22) {
                Text("\(reviewedCount)")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.deckAccent)

                Text("\(remainingCount)")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.remainingAccent)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 24)
        .listRowInsets(EdgeInsets(top: 10, leading: 18, bottom: 10, trailing: 18))
        .background(Color.deckCard, in: RoundedRectangle(cornerRadius: 22))
    }

    private var reviewedCount: Int {
        let remainingReviewIDs = Set(
            queueState.cards
                .filter { queueState.reviewedCardIDs.contains($0.id) }
                .map(\.id)
        )
        return deck.studyCards.filter { remainingReviewIDs.contains($0.id.uuidString) }.count
    }

    private var remainingCount: Int {
        let reviewedCardIDs = Set(queueState.reviewedCardIDs)
        let remainingNewIDs = Set(
            queueState.cards
                .filter { !reviewedCardIDs.contains($0.id) }
                .map(\.id)
        )
        return deck.studyCards.filter { remainingNewIDs.contains($0.id.uuidString) }.count
    }
}
