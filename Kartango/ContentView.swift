//
//  ContentView.swift
//  Kartango
//
//  Created by Panida Rumriankit on 15/3/2569 BE.
//

import CoreData
import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.managedObjectContext) private var viewContext
    @State private var importer = DeckImporter()
    @State private var isImporterPresented = false
    @State private var selectedTab: AppTab = .decks
    @State private var queueState = QueueState()
    @State private var simulatedDate: Date?
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Deck.createdAt, ascending: false)],
        animation: .default
    )
    private var decks: FetchedResults<Deck>
    
    var body: some View {
        ZStack {
            selectedTabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.brightBeige.ignoresSafeArea())
            
            if selectedTab == .decks && !decks.isEmpty {
                addDeckButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 26)
                    .padding(.bottom, 132)
            }
            
            CustomTabBar(selectedTab: $selectedTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .onAppear {
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.ankiPackage],
            allowsMultipleSelection: false,
            onCompletion: handleImportResult
        )
        .onAppear(perform: syncQueueState)
        .onChange(of: decks.count) { _, _ in
            syncQueueState()
        }
        .onChange(of: queueSignature) { _, _ in
            syncQueueState()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Just reload from UserDefaults — widget already updated the queue
                let defaults = UserDefaults(suiteName: AppGroup.identifier)
                let loaded = QueueStore.load(from: defaults)
                if loaded.queueDate == queueDateKey(for: .now) {
                    queueState = loaded
                } else {
                    syncQueueState()
                }
            }
        }
        .onAppear {
            importer.onImportComplete = {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    syncQueueState()
                }
            }
        }
    }
    
    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedTab {
        case .decks:
            DecksView(
                decks: decks,
                queueState: queueState,
                importer: importer,
                onImportTapped: presentImporter,
                onDelete: deleteDecks
            )
        case .stats:
            StatsView(
                deckCount: decks.count,
                totalCardCount: totalCardCount,
                queueState: queueState,
                onRebuildTodayQueue: rebuildTodayQueue,
                onSimulateTomorrowQueue: simulateTomorrowQueue
            )
        case .settings:
            SettingsView()
        }
    }
    
    private var totalCardCount: Int {
        decks.reduce(0) { $0 + $1.studyCards.count }
    }

    private var queueSignature: [String] {
        decks
            .flatMap { deck in
                deck.sortedCards.map { card in
                    "\(deck.id.uuidString):\(card.id.uuidString)"
                }
            }
            .sorted()
    }
    
    private var addDeckButton: some View {
        Button(action: presentImporter) {
            Image(systemName: "plus")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.black.opacity(0.9))
                .frame(width: 72, height: 72)
                .background(Color.white, in: Circle())
                .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
    
    private func presentImporter() {
        isImporterPresented = true
    }
    
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let fileURL = urls.first else {
                return
            }
            
            importer.importDeck(from: fileURL, persistenceController: .shared)
        case .failure(let error):
            importer.importErrorMessage = error.localizedDescription
        }
    }
    
    private func deleteDecks(at offsets: IndexSet) {
        for offset in offsets {
            let deck = decks[offset]
            viewContext.delete(deck)
        }
        
        do {
            try viewContext.save()
        } catch {
            viewContext.rollback()
            importer.importErrorMessage = "Failed to delete the selected deck."
        }
    }

    private func syncQueueState() {
        let defaults = UserDefaults(suiteName: AppGroup.identifier)
        let existingState = QueueStore.load(from: defaults)
        let todayKey = queueDateKey(for: .now)
        let libraryCards = makeLibraryQueueCards(using: existingState.againCounts)
        let libraryCardIDs = Set(libraryCards.map(\.id))
        let preservedReviewedCardIDs = preservedReviewedCardIDs(
            from: existingState,
            libraryCardIDs: libraryCardIDs
        )

        guard !libraryCards.isEmpty else {
            let emptyState = QueueState(
                queueDate: todayKey,
                cards: [],
                completedCardIDs: [],
                reviewedCardIDs: preservedReviewedCardIDs,
                againCounts: existingState.againCounts
            )
            QueueStore.save(emptyState, to: defaults)
            WidgetCenter.shared.reloadAllTimelines()
            queueState = emptyState
            return
        }

        if existingState.queueDate == todayKey && !existingState.cards.isEmpty {
            // Check if queue is stale (new decks/cards added since last sync)
            let existingCardIDs = Set(existingState.cards.map(\.id))
            let queueIsStale = !libraryCardIDs.isSubset(of: existingCardIDs)

            if !queueIsStale && existingState.reviewedCardIDs == preservedReviewedCardIDs {
                queueState = existingState
                return
            }

            // Rebuild queue (new cards or migrated IDs)
            let preservedAgainCounts = existingState.againCounts.filter { libraryCardIDs.contains($0.key) }
            let rebuiltCards = buildDailyQueue(
                from: libraryCards,
                reviewedCardIDs: preservedReviewedCardIDs,
                againCounts: preservedAgainCounts,
                defaults: defaults
            )
            let rebuiltState = QueueState(
                queueDate: todayKey,
                cards: rebuiltCards,
                completedCardIDs: queueIsStale ? [] : existingState.completedCardIDs,
                reviewedCardIDs: preservedReviewedCardIDs,
                againCounts: preservedAgainCounts
            )
            QueueStore.save(rebuiltState, to: defaults)
            WidgetCenter.shared.reloadAllTimelines()
            queueState = rebuiltState
            return
        }

        // Day changed — save unfinished cards for tomorrow
        if !existingState.cards.isEmpty && existingState.queueDate != todayKey {
            let reviewedSet = Set(existingState.reviewedCardIDs)
            let unfinishedIDs = existingState.cards
                .filter { !reviewedSet.contains($0.id) }
                .map(\.id)
            defaults?.set(unfinishedIDs, forKey: "pendingCardIDs")
        }

        let preservedAgainCounts = existingState.againCounts.filter { libraryCardIDs.contains($0.key) }
        let rebuiltCards = buildDailyQueue(
            from: libraryCards,
            reviewedCardIDs: preservedReviewedCardIDs,
            againCounts: preservedAgainCounts,
            defaults: defaults
        )
        let rebuiltState = QueueState(
            queueDate: todayKey,
            cards: rebuiltCards,
            completedCardIDs: [],
            reviewedCardIDs: preservedReviewedCardIDs,
            againCounts: preservedAgainCounts
        )
        QueueStore.save(rebuiltState, to: defaults)
        WidgetCenter.shared.reloadAllTimelines()
        queueState = rebuiltState
    }

    private func rebuildTodayQueue() {
        simulatedDate = nil
        rebuildQueue(for: .now)
    }

    private func simulateTomorrowQueue() {
        let baseDate = simulatedDate ?? Date()
        guard let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: baseDate) else {
            return
        }
        simulatedDate = nextDay
        rebuildQueue(for: nextDay)
    }

    private func rebuildQueue(for date: Date) {
        let defaults = UserDefaults(suiteName: AppGroup.identifier)
        let existingState = QueueStore.load(from: defaults)
        let queueKey = queueDateKey(for: date)
        let libraryCards = makeLibraryQueueCards(using: existingState.againCounts)
        let libraryCardIDs = Set(libraryCards.map(\.id))
        let preservedAgainCounts = existingState.againCounts.filter { libraryCardIDs.contains($0.key) }
        let preservedReviewedCardIDs = preservedReviewedCardIDs(
            from: existingState,
            libraryCardIDs: libraryCardIDs
        )

        let rebuiltCards = buildDailyQueue(
            from: libraryCards,
            reviewedCardIDs: preservedReviewedCardIDs,
            againCounts: preservedAgainCounts,
            defaults: defaults
        )
        let rebuiltState = QueueState(
            queueDate: queueKey,
            cards: rebuiltCards,
            completedCardIDs: [],
            reviewedCardIDs: preservedReviewedCardIDs,
            againCounts: preservedAgainCounts
        )

        QueueStore.save(rebuiltState, to: defaults)
        WidgetCenter.shared.reloadAllTimelines()
        queueState = rebuiltState
    }

    private func makeLibraryQueueCards(using againCounts: [String: Int]) -> [QueueCard] {
        decks
            .flatMap { deck in
                deck.studyCards.map { card in
                    QueueCard(
                        id: card.id.uuidString,
                        deckID: deck.id.uuidString,
                        word: card.word,
                        reading: card.example ?? "",
                        meaning: card.definitionText,
                        audioFileName: card.audioFileName
                    )
                }
            }
            .sorted { lhs, rhs in
                let lhsAgainCount = againCounts[lhs.id, default: 0]
                let rhsAgainCount = againCounts[rhs.id, default: 0]

                if lhsAgainCount != rhsAgainCount {
                    return lhsAgainCount > rhsAgainCount
                }

                if lhs.deckID != rhs.deckID {
                    return lhs.deckID < rhs.deckID
                }

                return lhs.word.localizedCaseInsensitiveCompare(rhs.word) == .orderedAscending
            }
    }

    private func buildDailyQueue(
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
        let pendingCardIDs = Set(defaults?.stringArray(forKey: "pendingCardIDs") ?? [])

        // Group cards by deck, apply limits per deck
        let cardsByDeck = Dictionary(grouping: cards, by: \.deckID)
        var selectedReviewCards: [QueueCard] = []
        var selectedNewCards: [QueueCard] = []

        for (_, deckCards) in cardsByDeck {
            let deckReviewCards = deckCards.filter { reviewedCardIDSet.contains($0.id) }
            let deckNewCards = deckCards.filter { !reviewedCardIDSet.contains($0.id) }

            selectedReviewCards.append(contentsOf: weightedReviewSelection(
                from: deckReviewCards,
                againCounts: againCounts,
                limit: reviewCardsPerDay
            ))

            // Prioritize pending cards from yesterday, then fill with new cards
            let pendingCards = deckNewCards.filter { pendingCardIDs.contains($0.id) }
            let otherNewCards = deckNewCards.filter { !pendingCardIDs.contains($0.id) }
            selectedNewCards.append(contentsOf: Array((pendingCards + otherNewCards).prefix(newCardsPerDay)))
        }

        // Clear pending after use
        defaults?.removeObject(forKey: "pendingCardIDs")

        return selectedReviewCards + selectedNewCards
    }

    private func weightedReviewSelection(
        from reviewCards: [QueueCard],
        againCounts: [String: Int],
        limit: Int
    ) -> [QueueCard] {
        guard reviewCards.count > limit else {
            return reviewCards
        }

        var generator = SystemRandomNumberGenerator()
        var remainingCards = reviewCards
        var selectedCards: [QueueCard] = []

        while selectedCards.count < limit, !remainingCards.isEmpty {
            let totalWeight = remainingCards.reduce(0) { partialResult, card in
                partialResult + max(1, againCounts[card.id, default: 0] + 1)
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

    private func preservedReviewedCardIDs(
        from existingState: QueueState,
        libraryCardIDs: Set<String>
    ) -> [String] {
        let reviewedIDs = Set(existingState.reviewedCardIDs)
        let migratedIDs = reviewedIDs.union(existingState.againCounts.keys)
        return migratedIDs.filter { libraryCardIDs.contains($0) }.sorted()
    }

    private func normalizedDailyLimit(_ value: Int) -> Int {
        let allowedValues = [10, 20, 30, 40, 50]
        return allowedValues.contains(value) ? value : 10
    }

    private func queueDateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private extension UTType {
    static let ankiPackage = UTType(filenameExtension: "apkg") ?? .data
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
