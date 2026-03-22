import CoreData
import Foundation
import SQLite
import ZIPFoundation

actor APKGParser {
    private static let appGroupIdentifier = "group.com.ske.kartango"
    private static let audioDirectoryName = "ImportedAudio"

    struct ImportSummary {
        let deckCount: Int
        let cardCount: Int
    }

    struct ParsedCard {
        let noteID: Int64
        let cardID: Int64
        let word: String
        let definitionText: String
        let example: String?
        let audioFileName: String?
    }

    struct ParsedDeck {
        let name: String
        let cards: [ParsedCard]
    }

    enum ParserError: LocalizedError {
        case missingCollectionDatabase
        case missingRequiredTable(String)
        case malformedMediaIndex
        case missingAppGroupContainer
        case noCardsFound

        var errorDescription: String? {
            switch self {
            case .missingCollectionDatabase:
                return "The Anki package is missing collection.anki2."
            case .missingRequiredTable(let table):
                return "The Anki database is missing the required \(table) table."
            case .malformedMediaIndex:
                return "The Anki package contains an invalid media index."
            case .missingAppGroupContainer:
                return "The shared App Group container could not be opened."
            case .noCardsFound:
                return "No cards were found in the imported deck."
            }
        }
    }

    func importDeck(
        from archiveURL: URL,
        suggestedDeckName: String,
        persistenceController: PersistenceController
    ) async throws -> ImportSummary {
        let preparedImport = try await Task.detached(priority: .userInitiated) {
            try Self.prepareImport(from: archiveURL, suggestedDeckName: suggestedDeckName)
        }.value

        defer {
            try? FileManager.default.removeItem(at: preparedImport.workingDirectory)
        }

        try await persistenceController.importDecks(decks: preparedImport.decks)

        let cardCount = preparedImport.decks.reduce(into: 0) { partialResult, deck in
            partialResult += deck.cards.count
        }

        return ImportSummary(deckCount: preparedImport.decks.count, cardCount: cardCount)
    }

    private static func prepareImport(from archiveURL: URL, suggestedDeckName: String) throws -> (workingDirectory: URL, decks: [ParsedDeck]) {
        let fileManager = FileManager.default
        let workingDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: workingDirectory, withIntermediateDirectories: true)

        let archive = try ZIPFoundation.Archive(url: archiveURL, accessMode: ZIPFoundation.Archive.AccessMode.read)

        try extractAll(from: archive, to: workingDirectory)

        let collectionURL = try collectionDatabaseURL(in: workingDirectory)

        let mediaMap = try parseMediaMap(in: workingDirectory)
        let audioDirectory = try sharedAudioDirectory()
        let decks = try parseDecks(
            collectionURL: collectionURL,
            mediaMap: mediaMap,
            extractedFilesDirectory: workingDirectory,
            audioDirectory: audioDirectory,
            fallbackDeckName: suggestedDeckName
        )

        guard decks.contains(where: { !$0.cards.isEmpty }) else {
            throw ParserError.noCardsFound
        }

        return (workingDirectory, decks.filter { !$0.cards.isEmpty })
    }

    private static func collectionDatabaseURL(in directory: URL) throws -> URL {
        let candidateNames = [
            "collection.anki21",
            "collection.anki2"
        ]

        for candidateName in candidateNames {
            let candidateURL = directory.appendingPathComponent(candidateName)
            if FileManager.default.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
        }

        throw ParserError.missingCollectionDatabase
    }

    private static func extractAll(from archive: ZIPFoundation.Archive, to destinationDirectory: URL) throws {
        let fileManager = FileManager.default
        for entry in archive {
            let destinationURL = destinationDirectory.appendingPathComponent(entry.path)
            let destinationParent = destinationURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: destinationParent, withIntermediateDirectories: true)
            _ = try archive.extract(entry, to: destinationURL)
        }
    }

    private static func parseMediaMap(in directory: URL) throws -> [String: String] {
        let mediaURL = directory.appendingPathComponent("media")
        guard FileManager.default.fileExists(atPath: mediaURL.path) else {
            return [:]
        }

        let data = try Data(contentsOf: mediaURL)

        do {
            let decoded = try JSONDecoder().decode([String: String].self, from: data)
            return Dictionary(uniqueKeysWithValues: decoded.map { ($1, $0) })
        } catch {
            throw ParserError.malformedMediaIndex
        }
    }

    private static func sharedAudioDirectory() throws -> URL {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier) else {
            throw ParserError.missingAppGroupContainer
        }

        let audioDirectory = containerURL.appendingPathComponent(Self.audioDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
        return audioDirectory
    }

    private static func parseDecks(
        collectionURL: URL,
        mediaMap: [String: String],
        extractedFilesDirectory: URL,
        audioDirectory: URL,
        fallbackDeckName: String
    ) throws -> [ParsedDeck] {
        let database = try SQLite.Connection(collectionURL.path, readonly: true)

        try ensureTableExists("notes", in: database)
        try ensureTableExists("cards", in: database)
        try ensureTableExists("col", in: database)

        let deckNames = try parseDeckNames(in: database)
        let rows = try database.prepare("""
            SELECT notes.id AS note_id, cards.id AS card_id, cards.did AS deck_id, notes.flds AS fields
            FROM notes
            JOIN cards ON cards.nid = notes.id
            ORDER BY cards.did, notes.id
            """)

        var copiedAudioBySourceName: [String: String] = [:]
        var cardsByDeckName: [String: [ParsedCard]] = [:]

        for row in rows {
            guard
                let noteID = row[0] as? Int64,
                let cardID = row[1] as? Int64,
                let deckID = row[2] as? Int64,
                let fields = row[3] as? String
            else {
                continue
            }

            let separatedFields = fields.components(separatedBy: "\u{1F}")
            guard separatedFields.count >= 2 else {
                continue
            }

            let wordField = separatedFields[0]
            let definitionField = separatedFields[1]
            let exampleField = separatedFields.count > 2 ? separatedFields[2] : nil
            let referencedAudio = extractAudioFileName(from: separatedFields)
            let copiedAudio = try copyAudioIfNeeded(
                referencedAudio,
                mediaMap: mediaMap,
                extractedFilesDirectory: extractedFilesDirectory,
                audioDirectory: audioDirectory,
                cache: &copiedAudioBySourceName
            )

            let deckName = deckNames[deckID] ?? fallbackDeckName
            let card = ParsedCard(
                noteID: noteID,
                cardID: cardID,
                word: normalizedText(from: wordField),
                definitionText: normalizedText(from: definitionField),
                example: normalizedOptionalText(from: exampleField),
                audioFileName: copiedAudio
            )
            cardsByDeckName[deckName, default: []].append(card)
        }

        return cardsByDeckName
            .map { ParsedDeck(name: $0.key, cards: $0.value) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func ensureTableExists(_ tableName: String, in database: SQLite.Connection) throws {
        let query = try database.scalar(
            "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = ?",
            tableName
        ) as? Int64

        guard query == 1 else {
            throw ParserError.missingRequiredTable(tableName)
        }
    }

    private static func parseDeckNames(in database: SQLite.Connection) throws -> [Int64: String] {
        guard
            let row = try database.prepare("SELECT decks FROM col LIMIT 1").makeIterator().next(),
            let decksJSON = row[0] as? String
        else {
            return [:]
        }

        guard
            let data = decksJSON.data(using: String.Encoding.utf8),
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return [:]
        }

        return json.reduce(into: [Int64: String]()) { result, entry in
            guard
                let deckID = Int64(entry.key),
                let deckData = entry.value as? [String: Any],
                let deckName = deckData["name"] as? String,
                !deckName.isEmpty
            else {
                return
            }

            result[deckID] = deckName
        }
    }

    private static func extractAudioFileName(from fields: [String]) -> String? {
        let pattern = #"\[sound:([^\]]+)\]"#

        for field in fields {
            guard let match = field.range(of: pattern, options: .regularExpression) else {
                continue
            }

            let value = String(field[match])
            return value
                .replacingOccurrences(of: "[sound:", with: "")
                .replacingOccurrences(of: "]", with: "")
        }

        return nil
    }

    private static func copyAudioIfNeeded(
        _ sourceFileName: String?,
        mediaMap: [String: String],
        extractedFilesDirectory: URL,
        audioDirectory: URL,
        cache: inout [String: String]
    ) throws -> String? {
        guard let sourceFileName else {
            return nil
        }

        if let cachedFileName = cache[sourceFileName] {
            return cachedFileName
        }

        guard let archivedFileName = mediaMap[sourceFileName] else {
            return nil
        }

        let sourceURL = extractedFilesDirectory.appendingPathComponent(archivedFileName)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            return nil
        }

        let destinationFileName = UUID().uuidString + "-" + sourceFileName.replacingOccurrences(of: "/", with: "-")
        let destinationURL = audioDirectory.appendingPathComponent(destinationFileName)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        cache[sourceFileName] = destinationFileName
        return destinationFileName
    }

    private static func normalizedOptionalText(from field: String?) -> String? {
        guard let field else {
            return nil
        }

        let normalized = normalizedText(from: field)
        return normalized.isEmpty ? nil : normalized
    }

    private static func normalizedText(from field: String) -> String {
        let withoutAudio = field.replacingOccurrences(
            of: #"\[sound:[^\]]+\]"#,
            with: "",
            options: .regularExpression
        )
        let withoutMarkup = withoutAudio.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: " ",
            options: .regularExpression
        )

        return withoutMarkup
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
