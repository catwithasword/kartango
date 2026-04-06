//
//  KartangoWidget.swift
//  KartangoWidget
//
//  Created by Panida Rumriankit on 15/3/2569 BE.
//

import WidgetKit
import SwiftUI
import AppIntents



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
    
    
//    func getTimeline(in context: Context, completion: @escaping (Timeline<CardEntry>) -> ()) {
//        let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
//        let state = QueueStore.load(from: defaults)
//        let currentCard = state.currentCard
//        let isFlipped = defaults.bool(forKey: AppGroup.isFlippedKey)
//        
//        let entry = CardEntry(
//            date: Date(),
//            isFlipped: isFlipped && currentCard != nil,
//            word: currentCard?.word ?? "Queue complete",
//            reading: currentCard?.reading ?? "",
//            meaning: currentCard?.meaning ?? "",
//            hasCard: currentCard != nil
//        )
//        
//        completion(Timeline(entries: [entry], policy: .never))
//    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<CardEntry>) -> ()) {
        
        // TEMPORARY RESET - step 1
//        let resetDefaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
//        var resetState = QueueStore.load(from: resetDefaults)
//        resetState = QueueState(
//            queueDate: "2000-01-01",
//            cards: resetState.cards,
//            completedCardIDs: resetState.completedCardIDs,
//            reviewedCardIDs: resetState.reviewedCardIDs,
//            againCounts: resetState.againCounts
//        )
//        QueueStore.save(resetState, to: resetDefaults)
//        
        
        let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
        var state = QueueStore.load(from: defaults)
//        let todayKey = QueueBuilder.queueDateKey(for: .now)
        let todayKey = QueueBuilder.queueDateKey(for: Calendar.current.date(byAdding: .day, value: -1, to: .now)!)

        // DEBUG - remove after testing
        let data = defaults.data(forKey: "allLibraryCards") ?? Data()
        let allCards = (try? JSONDecoder().decode([QueueCard].self, from: data)) ?? []
        print("🃏 allLibraryCards count: \(allCards.count)")
        print("📅 state.queueDate: \(state.queueDate)")
        print("📅 todayKey: \(todayKey)")
        print("🔄 will rebuild: \(state.queueDate != todayKey)")
        print("📦 current queue count: \(state.cards.count)")
        
        
        
        // Rebuild queue if it's a new day
        if state.queueDate != todayKey {
            let data = defaults.data(forKey: "allLibraryCards") ?? Data()
            let allCards = (try? JSONDecoder().decode([QueueCard].self, from: data)) ?? []

            let rebuiltCards = QueueBuilder.buildDailyQueue(
                from: allCards,
                reviewedCardIDs: state.reviewedCardIDs,
                againCounts: state.againCounts,
                defaults: defaults
            )
            state = QueueState(
                queueDate: todayKey,
                cards: rebuiltCards,
                completedCardIDs: [],
                reviewedCardIDs: state.reviewedCardIDs,
                againCounts: state.againCounts
            )
            QueueStore.save(state, to: defaults)
        }

        let isFlipped = defaults.bool(forKey: AppGroup.isFlippedKey)
        let currentCard = state.currentCard

        let entry = CardEntry(
            date: Date(),
            isFlipped: isFlipped && currentCard != nil,
            word: currentCard?.word ?? "Open app to refresh",
            reading: currentCard?.reading ?? "",
            meaning: currentCard?.meaning ?? "",
            hasCard: currentCard != nil
        )

        // Wake up at midnight to rebuild tomorrow's queue
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        let midnight = Calendar.current.startOfDay(for: tomorrow)
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
}




struct PlayAudioIntent: AppIntent {
    static var title: LocalizedStringResource = "Play Audio"
    
    func perform() async throws -> some IntentResult {
        // trigger audio here (App Group / shared state / etc.)
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
                
                VStack(spacing: 4) {
                    // Text("ひと")
                    Text(entry.reading)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    //  Text("人")
                    Text(entry.word)
                        .font(.system(size: 40, weight: .bold))
                    // Text("person")
                    Text(entry.meaning)
                        .font(.headline)
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button(intent: FlipCardIntent()) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }.buttonStyle(.borderless)
                    
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

