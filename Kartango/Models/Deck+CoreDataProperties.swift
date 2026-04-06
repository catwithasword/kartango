import CoreData
import Foundation

extension Deck {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Deck> {
        NSFetchRequest<Deck>(entityName: "Deck")
    }

    @NSManaged public var createdAt: Date
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var cards: Set<Card>?
}

extension Deck: Identifiable {
    var sortedCards: [Card] {
        (cards ?? []).sorted { $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending }
    }

    var studyCards: [Card] {
        sortedCards.filter(\.isIncludedInStudyQueue)
    }
}

extension Card {
    var isIncludedInStudyQueue: Bool {
        !word.localizedCaseInsensitiveContains("Welcome to Kaishi")
    }
}
