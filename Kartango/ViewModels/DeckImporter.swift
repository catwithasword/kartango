import CoreData
import Foundation
import Observation
import WidgetKit

@MainActor
@Observable
final class DeckImporter {
    var isImporting = false
    var importErrorMessage: String?

    private let parser = APKGParser()

    func importDeck(from fileURL: URL, persistenceController: PersistenceController) {
        isImporting = true
        importErrorMessage = nil

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
                _ = try await parser.importDeck(
                    from: fileURL,
                    suggestedDeckName: suggestedDeckName,
                    persistenceController: persistenceController
                )
                // connect to widget

                let context = persistenceController.container.viewContext

                let request: NSFetchRequest<Card> = Card.fetchRequest()
                request.fetchLimit = 1

                if let card = try? context.fetch(request).first {
                    let defaults = UserDefaults(suiteName: AppGroup.identifier)

                    defaults?.set(card.word, forKey: "word")
                    defaults?.set(card.definitionText, forKey: "meaning")
                    defaults?.set(card.example ?? "", forKey: "reading")

                    defaults?.set(false, forKey: "isFlipped")
                    defaults?.set(0, forKey: "currentIndex")
                }

                // 🔥 
                WidgetCenter.shared.reloadAllTimelines()
            } catch {
                importErrorMessage = error.localizedDescription
            }
        }
    }
}
