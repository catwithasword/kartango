import CoreData
import SwiftUI

struct DecksView: View {
    let decks: FetchedResults<Deck>
    let importer: DeckImporter
    let onImportTapped: () -> Void
    let onDelete: (IndexSet) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brightBeige
                    .ignoresSafeArea()

                if decks.isEmpty {
                    emptyDeckState
                } else {
                    deckList
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

    private var deckList: some View {
        List {
            statusSection

            Section("Decks") {
                ForEach(decks) { deck in
                    DeckRowView(deck: deck)
                        .listRowBackground(Color.deckCard)
                }
                .onDelete(perform: onDelete)
            }
        }
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 140)
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
            if let errorMessage = importer.importErrorMessage {
                infoCard(text: errorMessage, tint: .red)
            }

            Spacer()

            Button(action: onImportTapped) {
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

    private func infoCard(text: String, tint: Color) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.deckCard, in: RoundedRectangle(cornerRadius: 18))
    }
}
