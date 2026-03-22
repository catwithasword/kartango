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
    @StateObject private var importer = DeckImporter()
    @State private var isImporterPresented = false

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Deck.createdAt, ascending: false)],
        animation: .default
    )
    private var decks: FetchedResults<Deck>

    var body: some View {
        TabView {
            decksTab
                .tabItem {
                    Label("Decks", systemImage: "square.stack.fill")
                }

            statsTab
                .tabItem {
                    Label("Stats", systemImage: "chart.pie.fill")
                }

            settingsTab
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(Color.deckAccent)
        .background(Color.brightBeige.ignoresSafeArea())
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.ankiPackage],
            allowsMultipleSelection: false
        ) { result in
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
    }

    private var decksTab: some View {
        NavigationStack {
            ZStack {
                Color.brightBeige
                    .ignoresSafeArea()

                if decks.isEmpty {
                    emptyDeckState
                } else {
                    List {
                        statusSection
                        Section("Decks") {
                            ForEach(decks) { deck in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(deck.name)
                                        .font(.headline)
                                    Text("\(deck.sortedCards.count) cards")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    if let firstCard = deck.sortedCards.first {
                                        Text("\(firstCard.word) • \(firstCard.definitionText)")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                .padding(.vertical, 6)
                                .listRowBackground(Color.deckCard)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }

                if importer.isImporting {
                    ProgressView("Importing Deck...")
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                }
            }
            .navigationTitle("Kartango")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isImporterPresented = true
                    } label: {
                        Label("Import Deck", systemImage: "square.and.arrow.down")
                    }
                    .disabled(importer.isImporting)
                }
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if let summary = importer.importSummaryMessage {
            Section {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
        }

        if let errorMessage = importer.importErrorMessage {
            Section {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
        }
    }

    private var emptyDeckState: some View {
        VStack(spacing: 18) {
            statusCards

            Spacer()

            Button {
                isImporterPresented = true
            } label: {
                VStack(spacing: 10) {
                    Image("UploadIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                    Text("Upload deck (.apkg)")
                        .font(.headline)
                }
                .foregroundStyle(Color.deckAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(Color.deckCard, in: RoundedRectangle(cornerRadius: 28))
                .overlay {
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.deckAccent.opacity(0.18), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)

            Text("Import an Anki package to extract cards and shared audio.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    @ViewBuilder
    private var statusCards: some View {
        if let summary = importer.importSummaryMessage {
            infoCard(text: summary, tint: .green)
        }

        if let errorMessage = importer.importErrorMessage {
            infoCard(text: errorMessage, tint: .red)
        }
    }

    private var statsTab: some View {
        NavigationStack {
            ZStack {
                Color.brightBeige
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    statTile(title: "Decks", value: "\(decks.count)")
                    statTile(title: "Cards", value: "\(decks.reduce(0) { $0 + $1.sortedCards.count })")
                }
                .padding(24)
            }
            .navigationTitle("Stats")
        }
    }

    private var settingsTab: some View {
        NavigationStack {
            ZStack {
                Color.brightBeige
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    Text("Settings")
                        .font(.title2.weight(.semibold))
                    Text("App Group audio sharing is enabled for imported deck audio.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(24)
            }
            .navigationTitle("Settings")
        }
    }

    private func infoCard(text: String, tint: Color) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.deckCard, in: RoundedRectangle(cornerRadius: 18))
    }

    private func statTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(Color.deckAccent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(Color.deckCard, in: RoundedRectangle(cornerRadius: 24))
    }
}

private extension UTType {
    static let ankiPackage = UTType(filenameExtension: "apkg") ?? .data
}

private extension Color {
    static let brightBeige = Color(
        red: 1.0,
        green: 244.0 / 255.0,
        blue: 234.0 / 255.0
    )

    static let deckAccent = Color(
        red: 116.0 / 255.0,
        green: 156.0 / 255.0,
        blue: 172.0 / 255.0
    )

    static let deckCard = Color.white.opacity(0.8)
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
