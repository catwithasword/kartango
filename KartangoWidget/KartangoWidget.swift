//
//  KartangoWidget.swift
//  KartangoWidget
//
//  Created by Panida Rumriankit on 15/3/2569 BE.
//

import WidgetKit
import SwiftUI
import AppIntents
import AVFAudio



struct Provider: TimelineProvider {
    
    func placeholder(in context: Context) -> CardEntry {
        CardEntry(
            date: Date(),
            isFlipped: false,
            word: "人",
            reading: "ひと",
            meaning: "person",
            hasCard: true
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (CardEntry) -> ()) {
        completion(
            CardEntry(
                date: Date(),
                isFlipped: false,
                word: "人",
                reading: "ひと",
                meaning: "person",
                hasCard: true
            )
        )
    }
    
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<CardEntry>) -> ()) {
        let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
        let state = QueueStore.load(from: defaults)
        let currentCard = state.currentCard
        let isFlipped = defaults.bool(forKey: AppGroup.isFlippedKey)
        
        let entry = CardEntry(
            date: Date(),
            isFlipped: isFlipped && currentCard != nil,
            word: currentCard?.word ?? "Queue complete",
            reading: currentCard?.reading ?? "",
            meaning: currentCard?.meaning ?? "",
            hasCard: currentCard != nil
        )
        
        completion(Timeline(entries: [entry], policy: .never))
    }
}




struct PlayAudioIntent: AppIntent {
    static var title: LocalizedStringResource = "Play Audio"
    // NO openAppWhenRun — stays in background ✅

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
        let state = QueueStore.load(from: defaults)

        guard let audioFileName = state.currentCard?.audioFileName,
              !audioFileName.isEmpty else { return .result() }

        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroup.identifier
        ) else { return .result() }

        let fileURL = containerURL
            .appendingPathComponent("ImportedAudio")
            .appendingPathComponent(audioFileName)

        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .result() }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: fileURL)
            player.prepareToPlay()
            player.play()

            // Keep alive until audio finishes
            let duration = player.duration
            try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        } catch {
            print("Audio error: \(error)")
        }

        return .result()
    }
}


// Flip
struct FlipCardIntent: AppIntent {
    static var title: LocalizedStringResource = "Flip Card"
    
    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
        guard QueueStore.load(from: defaults).currentCard != nil else {
            return .result()
        }
        
        let current = defaults.bool(forKey: AppGroup.isFlippedKey)
        defaults.set(!current, forKey: AppGroup.isFlippedKey)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}


// Again
struct AgainIntent: AppIntent {
    static var title: LocalizedStringResource = "Again"
    
    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
        var state = QueueStore.load(from: defaults)
        
        guard let currentCard = state.currentCard else {
            return .result()
        }
        
        state.cards.removeFirst()
        state.againCounts[currentCard.id, default: 0] += 1
        if !state.reviewedCardIDs.contains(currentCard.id) {
            state.reviewedCardIDs.append(currentCard.id)
        }
        state.cards.append(currentCard)
        QueueStore.save(state, to: defaults)
        
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// Pass
struct PassIntent: AppIntent {
    static var title: LocalizedStringResource = "Pass"
    
    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
        
        var state = QueueStore.load(from: defaults)
        
        guard let currentCard = state.currentCard else {
            return .result()
        }
        
        state.cards.removeFirst()
        state.completedCardIDs.append(currentCard.id)
        if !state.reviewedCardIDs.contains(currentCard.id) {
            state.reviewedCardIDs.append(currentCard.id)
        }
        QueueStore.save(state, to: defaults)
        
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}


struct CardEntry: TimelineEntry {
    let date: Date
    let isFlipped: Bool
    let word: String
    let reading: String
    let meaning: String
    let hasCard: Bool
}


struct KartangoWidgetEntryView: View {
    var entry: Provider.Entry
    
    // MAIN BODY
    var body: some View {
        ZStack {
            if entry.isFlipped {
                backView
            } else {
                frontView
            }
        }
        .containerBackground(.clear, for: .widget)
        .contentTransition(.opacity)    // or .blur(.systemThickMaterial)
        .animation(.easeInOut(duration: 0.3), value: entry.isFlipped)
    }
    
    // FRONT VIEW
    @ViewBuilder
    var frontView: some View {
        Button(intent: FlipCardIntent()) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.widgetBackground)
                    .padding(-20)
                
                if !entry.hasCard {
                    // Label("All done for today!!", systemImage: "checkmark.circle.fill")
                    // .font(.headline)
//                    Text("Import a deck in the app to refill today's queue.")
                    Text("All done for today!!")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(24)
                } else {
                    Text(entry.word)
                        .font(.system(size: 50, weight: .bold))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    var backView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.widgetBackground)
                .padding(-20)

            HStack {
                Button(intent: PlayAudioIntent()) {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.audioButton)
                        .clipShape(Circle())
                }
                .buttonStyle(.borderless)

                Spacer()

                // Center content flips card when tapped
                Button(intent: FlipCardIntent()) {
                    VStack(spacing: 4) {
                        Text(entry.reading)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(entry.word)
                            .font(.system(size: 40, weight: .bold))
                        Text(entry.meaning)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 12) {
                    Button(intent: AgainIntent()) {
                        Image(systemName: "arrow.uturn.left")
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.againButton)
                            .clipShape(Circle())
                    }.buttonStyle(.borderless)

                    Button(intent: PassIntent()) {
                        Image(systemName: "arrow.right")
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.passButton)
                            .clipShape(Circle())
                    }.buttonStyle(.borderless)
                }
            }
            .padding()
        }
    }
    
    
}


struct KartangoWidget: Widget {
    let kind: String = "KartangoWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(macOS 14.0, iOS 17.0, *) {
                KartangoWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                KartangoWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("My Widget")
        .description("This is an example widget.")
    }
}

#Preview(as: .systemMedium) {
    KartangoWidget()
} timeline: {
    CardEntry(
        date: .now,
        isFlipped: false,
        word: "human",
        reading: "kon",
        meaning: "person",
        hasCard: true
    )
    CardEntry(
        date: .now,
        isFlipped: true,
        word: "human",
        reading: "kon",
        meaning: "person",
        hasCard: true
    )
}

