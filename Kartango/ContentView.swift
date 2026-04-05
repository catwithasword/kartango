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
    @Environment(\.managedObjectContext) private var viewContext
    @State private var importer = DeckImporter()
    @State private var isImporterPresented = false
    @State private var selectedTab: AppTab = .decks
    
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
            clearOldData()
            setupTodayQueue()
            processLastAction()     // optional but safe
            updateWidgetCard()      // push first card to widget
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.ankiPackage],
            allowsMultipleSelection: false,
            onCompletion: handleImportResult
        )
        
    }
    
    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedTab {
        case .decks:
            DecksView(
                decks: decks,
                importer: importer,
                onImportTapped: presentImporter,
                onDelete: deleteDecks
            )
        case .stats:
            StatsView(deckCount: decks.count, totalCardCount: totalCardCount)
        case .settings:
            SettingsView()
        }
    }
    
    private var totalCardCount: Int {
        decks.reduce(0) { $0 + $1.sortedCards.count }
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
    
    // test
    private func setupTodayQueue() {
        // Get shared storage between app + widget
        let defaults = UserDefaults(suiteName: AppGroup.identifier)
        
        // Don't reset if queue already exists
        if let existing = defaults?.stringArray(forKey: "todayQueue"), !existing.isEmpty {
            print("QUEUE ALREADY EXISTS, SKIPPING SETUP")
            return
        }

        let request: NSFetchRequest<Card> = Card.fetchRequest()
        request.fetchLimit = 10

        // Fetch cards from database
        if let cards = try? viewContext.fetch(request) {
            let words = cards.map { $0.word }
            let readings = cards.map { $0.example }
            let meanings = cards.map { $0.definitionText }
            
            // Save arrays into App Group (shared with widget)
            defaults?.set(words, forKey: "queueWords")
            defaults?.set(readings, forKey: "queueReadings")
            defaults?.set(meanings, forKey: "queueMeanings")

            let ids = cards.map { $0.id.uuidString }
            defaults?.set(ids, forKey: "todayQueue")
            defaults?.set(0, forKey: "currentIndex")
            defaults?.set(false, forKey: "isFlipped")

            print("TODAY QUEUE:", ids.count)
        }
    }

    // 2) Put CURRENT card into App Group (what widget reads)
    private func updateWidgetCard() {
        let defaults = UserDefaults(suiteName: AppGroup.identifier)

        let ids = defaults?.stringArray(forKey: "todayQueue") ?? []
        let index = defaults?.integer(forKey: "currentIndex") ?? 0
        
        // If we've reached the end of the queue
        guard index < ids.count else {
            defaults?.set("DONE", forKey: "word")
            defaults?.set("", forKey: "meaning")
            defaults?.set("", forKey: "reading")
            defaults?.set("", forKey: "currentCardID")
            WidgetCenter.shared.reloadAllTimelines()
            return
        }

        let idString = ids[index]
        guard let uuid = UUID(uuidString: idString) else { return }

        // Fetch the card from database
        let request: NSFetchRequest<Card> = Card.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)

        if let card = try? viewContext.fetch(request).first {
            defaults?.set(card.word, forKey: "word")
            defaults?.set(card.definitionText, forKey: "meaning")
            defaults?.set(card.example ?? "", forKey: "reading")
            defaults?.set(card.id.uuidString, forKey: "currentCardID")
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    // 3) (Optional now, useful later) process last action -> save to DB
    private func processLastAction() {
        let defaults = UserDefaults(suiteName: AppGroup.identifier)

        // Read what user did (saved earlier by widget)
        guard let cardIDString = defaults?.string(forKey: "lastActionCardID"),
              let action = defaults?.string(forKey: "lastActionType"),
              let uuid = UUID(uuidString: cardIDString) else { return }

        let request: NSFetchRequest<Card> = Card.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)

        if let card = try? viewContext.fetch(request).first {
            if action == "again" {
                print("AGAIN:", card.word)
                // TODO: update properties if you add them (e.g., againCount += 1)
            } else {
                print("PASS:", card.word)
                // TODO: mark doneToday = true (if you add field)
            }
            try? viewContext.save()
        }

        defaults?.removeObject(forKey: "lastActionCardID")
        defaults?.removeObject(forKey: "lastActionType")
    }
    
    private func clearOldData() {
        let defaults = UserDefaults(suiteName: AppGroup.identifier)
        // Wipe EVERYTHING in shared storage
        defaults?.removePersistentDomain(forName: AppGroup.identifier)
        print("CLEARED OLD DATA")
    }
}

private extension UTType {
    static let ankiPackage = UTType(filenameExtension: "apkg") ?? .data
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
