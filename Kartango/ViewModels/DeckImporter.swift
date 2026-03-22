import CoreData
import Foundation
import Combine

@MainActor
final class DeckImporter: ObservableObject {
    @Published var isImporting = false
    @Published var importErrorMessage: String?
    @Published var importSummaryMessage: String?

    private let parser = APKGParser()

    func importDeck(from fileURL: URL, persistenceController: PersistenceController) {
        isImporting = true
        importErrorMessage = nil
        importSummaryMessage = nil

        let hasScopedAccess = fileURL.startAccessingSecurityScopedResource()

        Task {
            defer {
                if hasScopedAccess {
                    fileURL.stopAccessingSecurityScopedResource()
                }

                isImporting = false
            }

            do {
                let suggestedDeckName = fileURL.deletingPathExtension().lastPathComponent
                let summary = try await parser.importDeck(
                    from: fileURL,
                    suggestedDeckName: suggestedDeckName,
                    persistenceController: persistenceController
                )

                importSummaryMessage = "Imported \(summary.cardCount) cards across \(summary.deckCount) deck(s)."
            } catch {
                importErrorMessage = error.localizedDescription
            }
        }
    }
}
