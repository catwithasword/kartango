//
//  QueueBuilder.swift
//  Kartango
//
//  Created by Mink on 6/4/2569 BE.
//

import Foundation

// QueueBuilder.swift — add to both App and Widget targets


struct QueueBuilder {
    static func buildDailyQueue(
        from cards: [QueueCard],
        reviewedCardIDs: [String],
        againCounts: [String: Int],
        defaults: UserDefaults?
    ) -> [QueueCard] {
        let newCardsPerDay = normalizedDailyLimit(
            defaults?.integer(forKey: "newCardsPerDay") ?? 10
        )
        let reviewCardsPerDay = normalizedDailyLimit(
            defaults?.integer(forKey: "reviewCardsPerDay") ?? 10
        )

        let reviewedCardIDSet = Set(reviewedCardIDs)
        let reviewCards = cards.filter { reviewedCardIDSet.contains($0.id) }
        let newCards = cards.filter { !reviewedCardIDSet.contains($0.id) }

        let selectedReviewCards = weightedReviewSelection(
            from: reviewCards,
            againCounts: againCounts,
            limit: reviewCardsPerDay
        )
        let selectedReviewIDs = Set(selectedReviewCards.map(\.id))
        let selectedNewCards = Array(
            newCards
                .filter { !selectedReviewIDs.contains($0.id) }
                .prefix(newCardsPerDay)
        )

        return selectedReviewCards + selectedNewCards
    }

    static func normalizedDailyLimit(_ value: Int) -> Int {
        let allowedValues = [10, 20, 30, 40, 50]
        return allowedValues.contains(value) ? value : 10
    }

    static func queueDateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func weightedReviewSelection(
        from reviewCards: [QueueCard],
        againCounts: [String: Int],
        limit: Int
    ) -> [QueueCard] {
        guard reviewCards.count > limit else { return reviewCards }

        var generator = SystemRandomNumberGenerator()
        var remainingCards = reviewCards
        var selectedCards: [QueueCard] = []

        while selectedCards.count < limit, !remainingCards.isEmpty {
            let totalWeight = remainingCards.reduce(0) {
                $0 + max(1, againCounts[$1.id, default: 0] + 1)
            }
            var randomWeight = Int.random(in: 0..<totalWeight, using: &generator)

            for (index, card) in remainingCards.enumerated() {
                randomWeight -= max(1, againCounts[card.id, default: 0] + 1)
                if randomWeight < 0 {
                    selectedCards.append(card)
                    remainingCards.remove(at: index)
                    break
                }
            }
        }

        return selectedCards
    }
}
