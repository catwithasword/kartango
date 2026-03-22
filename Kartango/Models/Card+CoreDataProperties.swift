import CoreData
import Foundation

extension Card {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Card> {
        NSFetchRequest<Card>(entityName: "Card")
    }

    @NSManaged public var audioFileName: String?
    @NSManaged public var cardID: Int64
    @NSManaged public var createdAt: Date
    @NSManaged public var definitionText: String
    @NSManaged public var example: String?
    @NSManaged public var id: UUID
    @NSManaged public var noteID: Int64
    @NSManaged public var word: String
    @NSManaged public var deck: Deck
}

extension Card: Identifiable {}
