//
//  Persistence.swift
//  Kartango
//
//  Created by Panida Rumriankit on 15/3/2569 BE.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    static let managedObjectModel: NSManagedObjectModel = {
        let model = NSManagedObjectModel()

        let deckEntity = NSEntityDescription()
        deckEntity.name = "Deck"
        deckEntity.managedObjectClassName = NSStringFromClass(Deck.self)

        let cardEntity = NSEntityDescription()
        cardEntity.name = "Card"
        cardEntity.managedObjectClassName = NSStringFromClass(Card.self)

        let deckID = NSAttributeDescription()
        deckID.name = "id"
        deckID.attributeType = .UUIDAttributeType
        deckID.isOptional = false

        let deckName = NSAttributeDescription()
        deckName.name = "name"
        deckName.attributeType = .stringAttributeType
        deckName.isOptional = false

        let deckCreatedAt = NSAttributeDescription()
        deckCreatedAt.name = "createdAt"
        deckCreatedAt.attributeType = .dateAttributeType
        deckCreatedAt.isOptional = false

        let cardAudioFileName = NSAttributeDescription()
        cardAudioFileName.name = "audioFileName"
        cardAudioFileName.attributeType = .stringAttributeType
        cardAudioFileName.isOptional = true

        let cardCardID = NSAttributeDescription()
        cardCardID.name = "cardID"
        cardCardID.attributeType = .integer64AttributeType
        cardCardID.isOptional = false

        let cardCreatedAt = NSAttributeDescription()
        cardCreatedAt.name = "createdAt"
        cardCreatedAt.attributeType = .dateAttributeType
        cardCreatedAt.isOptional = false

        let cardDefinitionText = NSAttributeDescription()
        cardDefinitionText.name = "definitionText"
        cardDefinitionText.attributeType = .stringAttributeType
        cardDefinitionText.isOptional = false

        let cardExample = NSAttributeDescription()
        cardExample.name = "example"
        cardExample.attributeType = .stringAttributeType
        cardExample.isOptional = true

        let cardID = NSAttributeDescription()
        cardID.name = "id"
        cardID.attributeType = .UUIDAttributeType
        cardID.isOptional = false

        let cardNoteID = NSAttributeDescription()
        cardNoteID.name = "noteID"
        cardNoteID.attributeType = .integer64AttributeType
        cardNoteID.isOptional = false

        let cardWord = NSAttributeDescription()
        cardWord.name = "word"
        cardWord.attributeType = .stringAttributeType
        cardWord.isOptional = false

        let deckCards = NSRelationshipDescription()
        deckCards.name = "cards"
        deckCards.destinationEntity = cardEntity
        deckCards.minCount = 0
        deckCards.maxCount = 0
        deckCards.deleteRule = .cascadeDeleteRule
        deckCards.isOptional = true
        deckCards.isOrdered = false

        let cardDeck = NSRelationshipDescription()
        cardDeck.name = "deck"
        cardDeck.destinationEntity = deckEntity
        cardDeck.minCount = 1
        cardDeck.maxCount = 1
        cardDeck.deleteRule = .nullifyDeleteRule
        cardDeck.isOptional = false

        deckCards.inverseRelationship = cardDeck
        cardDeck.inverseRelationship = deckCards

        deckEntity.properties = [deckID, deckName, deckCreatedAt, deckCards]
        cardEntity.properties = [
            cardAudioFileName,
            cardCardID,
            cardCreatedAt,
            cardDefinitionText,
            cardExample,
            cardID,
            cardNoteID,
            cardWord,
            cardDeck
        ]

        model.entities = [deckEntity, cardEntity]
        return model
    }()

    @MainActor
    static let preview: PersistenceController = {
        PersistenceController(inMemory: true)
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Kartango", managedObjectModel: Self.managedObjectModel)
        let storeDescription = NSPersistentStoreDescription()

        if inMemory {
            storeDescription.url = URL(fileURLWithPath: "/dev/null")
        } else {
            storeDescription.url = NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("Kartango.sqlite")
        }

        container.persistentStoreDescriptions = [storeDescription]
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func importDecks(decks: [APKGParser.ParsedDeck]) async throws {
        try await container.performBackgroundTask { context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

            for parsedDeck in decks {
                let deck = Deck(context: context)
                deck.id = UUID()
                deck.name = parsedDeck.name
                deck.createdAt = Date()

                for parsedCard in parsedDeck.cards {
                    let card = Card(context: context)
                    card.id = UUID()
                    card.noteID = parsedCard.noteID
                    card.cardID = parsedCard.cardID
                    card.word = parsedCard.word
                    card.definitionText = parsedCard.definitionText
                    card.example = parsedCard.example
                    card.audioFileName = parsedCard.audioFileName
                    card.createdAt = Date()
                    card.deck = deck
                }
            }

            if context.hasChanges {
                try context.save()
            }
        }
    }
}
