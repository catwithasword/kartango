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
                WidgetCenter.shared.reloadAllTimelines()
            } catch {
                importErrorMessage = error.localizedDescription
            }
        }
    }
}
