//
//  ContentView.swift
//  Kartango
//
//  Created by Panida Rumriankit on 15/3/2569 BE.
//

import CoreData
import SwiftUI
import UniformTypeIdentifiers

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

            if selectedTab == .decks {
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
}

private extension UTType {
    static let ankiPackage = UTType(filenameExtension: "apkg") ?? .data
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
