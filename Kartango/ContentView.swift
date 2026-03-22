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
    fileprivate enum Tab {
        case decks
        case stats
        case settings

        var title: String {
            switch self {
            case .decks:
                "Decks"
            case .stats:
                "Stats"
            case .settings:
                "Settings"
            }
        }

        var systemImage: String {
            switch self {
            case .decks:
                "DecksWhite"
            case .stats:
                "Statswhite"
            case .settings:
                "SettingWhite"
            }
        }

        var unselectedImage: String {
            switch self {
            case .decks:
                "DecksGray"
            case .stats:
                "StatsGray"
            case .settings:
                "SettingGray"
            }
        }
    }

    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var importer = DeckImporter()
    @State private var isImporterPresented = false
    @State private var selectedTab: Tab = .decks

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Deck.createdAt, ascending: false)],
        animation: .default
    )
    private var decks: FetchedResults<Deck>

    var body: some View {
        ZStack(alignment: .bottom) {
            selectedTabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.brightBeige.ignoresSafeArea())

            CustomTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
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

    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedTab {
        case .decks:
            decksTab
        case .stats:
            statsTab
        case .settings:
            settingsTab
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
                                deckRow(deck)
                                .listRowBackground(Color.deckCard)
                            }
                            .onDelete(perform: deleteDecks)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: 140)
                    }
                }

                if importer.isImporting {
                    ProgressView("Importing Deck...")
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var statusSection: some View {
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
                        .foregroundStyle(Color.defaultGray)
                }
                .foregroundStyle(Color.deckAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 140)
        }
    }

    @ViewBuilder
    private var statusCards: some View {
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
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 140)
                }
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
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 140)
                }
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

    private func deckRow(_ deck: Deck) -> some View {
        let reviewedCount = 0
        let remainingCount = deck.sortedCards.count

        return HStack(spacing: 16) {
            Text(deck.name)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.black.opacity(0.85))
                .lineLimit(1)

            Spacer(minLength: 12)

            HStack(spacing: 22) {
                Text("\(reviewedCount)")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.deckAccent)

                Text("\(remainingCount)")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.remainingAccent)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 24)
        .listRowInsets(EdgeInsets(top: 10, leading: 18, bottom: 10, trailing: 18))
        .background(Color.deckCard, in: RoundedRectangle(cornerRadius: 22))
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

private struct CustomTabBar: View {
    @Binding var selectedTab: ContentView.Tab
    private let tabs: [ContentView.Tab] = [.decks, .stats, .settings]

    var body: some View {
        GeometryReader { geometry in
            let tabWidth = geometry.size.width / CGFloat(tabs.count)

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.white.opacity(0.94))
                    .frame(height: 80)
                    .shadow(color: .black.opacity(0.16), radius: 4, x: 0, y: 6)

                HStack(spacing: 0) {
                    ForEach(Array(tabs.enumerated()), id: \.offset) { _, tab in
                        tabButton(tab)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 76)

                selectedTabButton
                    .frame(width: tabWidth, height: 104)
                    .offset(x: selectedOffsetX(tabWidth: tabWidth))
            }
        }
        .frame(height: 108)
    }

    private func selectedOffsetX(tabWidth: CGFloat) -> CGFloat {
        guard let index = tabs.firstIndex(where: { $0 == selectedTab }) else {
            return 0
        }

        return CGFloat(index) * tabWidth
    }

    private func tabButton(_ tab: ContentView.Tab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 5) {
                Image(tab.unselectedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)

                Text(tab.title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(Color.defaultGray)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(selectedTab == tab ? 0 : 1)
        }
        .buttonStyle(.plain)
    }

    private var selectedTabButton: some View {
        Button {
            selectedTab = selectedTab
        } label: {
            VStack(spacing: 4) {
                Image(selectedTab.systemImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)

                Text(selectedTab.title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(width: 84, height: 84)
            .background(
                Circle()
                    .fill(Color.deckAccent)
            )
            .shadow(color: .black.opacity(0.14), radius: 5, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
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

    static let defaultGray = Color(
        red: 204.0 / 255.0,
        green: 204.0 / 255.0,
        blue: 204.0 / 255.0
    )

    static let deckAccent = Color(
        red: 116.0 / 255.0,
        green: 156.0 / 255.0,
        blue: 172.0 / 255.0
    )

    static let remainingAccent = Color(
        red: 145.0 / 255.0,
        green: 191.0 / 255.0,
        blue: 137.0 / 255.0
    )

    static let deckCard = Color.white.opacity(0.8)
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
