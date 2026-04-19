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
import AVFoundation


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
        let todayKey = QueueBuilder.queueDateKey(for: .now)
//        let todayKey = QueueBuilder.queueDateKey(for: Calendar.current.date(byAdding: .day, value: -1, to: .now)!)

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



struct PlayAudioIntent: AudioPlaybackIntent { // <--- Change this
    static var title: LocalizedStringResource = "Play Audio"
    
    // This is required by AudioPlaybackIntent
    static var isDiscoverable: Bool = true
    
    func perform() async throws -> some IntentResult {
        print("🔊 INTENT START ------------------")

        let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
        let state = QueueStore.load(from: defaults)

        print("📦 currentCard exists:", state.currentCard != nil)
        print("📦 audioFileName:", state.currentCard?.audioFileName ?? "nil")

        guard let audioFileName = state.currentCard?.audioFileName else {
            print("❌ No audio file name")
            return .result()
        }

        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroup.identifier
        ) else {
            print("❌ No container URL")
            return .result()
        }

        let fileURL = containerURL
            .appendingPathComponent("ImportedAudio")
            .appendingPathComponent(audioFileName)

        print("📁 containerURL:", containerURL.path)
        print("📁 fileURL:", fileURL.path)
        print("📁 file exists:", FileManager.default.fileExists(atPath: fileURL.path))

        do {
            let session = AVAudioSession.sharedInstance()

            print("🎧 Setting audio session...")
//            try session.setCategory(.playback, mode: .default, options: [])
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try session.setActive(true)

            print("🎧 Session active ✅")

            let player = try AVAudioPlayer(contentsOf: fileURL)

            print("🎵 Player created")
            print("🎵 duration:", player.duration)

            player.prepareToPlay()

            let started = player.play()
            print("▶️ play() returned:", started)

            if !started {
                print("❌ Player failed to start")
            }

            while player.isPlaying {
                print("⏳ playing...")
                try await Task.sleep(nanoseconds: 500_000_000)
            }

            print("✅ playback finished")

        } catch {
            print("❌ AUDIO ERROR:", error)
        }

        return .result()
    }

//    func perform() async throws -> some IntentResult {
//        let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
//        let state = QueueStore.load(from: defaults)
//
//        guard let audioFileName = state.currentCard?.audioFileName,
//              let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)
//        else { return .result() }
//
//        let fileURL = containerURL.appendingPathComponent("ImportedAudio").appendingPathComponent(audioFileName)
//
//        do {
//            
//            
//            let session = AVAudioSession.sharedInstance()
////             Use .mixWithOthers to prevent interrupting other apps if desired
//            try session.setCategory(.playback, mode: .default, options: [])
//            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
//            try session.setActive(true)
//
////             CRITICAL: You must keep a strong reference to the player
////             during the duration of the task.
//            let player = try AVAudioPlayer(contentsOf: fileURL)
//            player.prepareToPlay()
//            player.play()
//
//            // Keep the intent alive while audio plays
//            while player.isPlaying {
//                try await Task.sleep(nanoseconds: 500_000_000) // Sleep 0.5s chunks
//            }
//        } catch {
//            print("Status 561015905 Fix: \(error)")
//        }
//
//        return .result()
//    }
}




//
//
//// Delegate that holds a strong ref to itself until playback ends
//final class AudioDelegate: NSObject, AVAudioPlayerDelegate {
//    private static var active: Set<AudioDelegate> = []
//    private let continuation: CheckedContinuation<Void, Error>
//    private let player: AVAudioPlayer // strong ref keeps player alive
//
//    init(continuation: CheckedContinuation<Void, Error>, player: AVAudioPlayer) {
//        self.continuation = continuation
//        self.player = player
//    }
//
//    static func retain(_ delegate: AudioDelegate) {
//        active.insert(delegate)
//    }
//
//    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
//        continuation.resume()
//        Self.active.remove(self)
//    }
//
//    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
//        continuation.resume(throwing: error ?? CancellationError())
//        Self.active.remove(self)
//    }
//}

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

            Button(intent: FlipCardIntent()) {
                Color.clear
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .zIndex(0)          // ← ADD

            HStack {
                Button(intent: PlayAudioIntent()) {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.audioButton)
                        .clipShape(Circle())
                }
                .buttonStyle(.borderless)
                .zIndex(2)      // ← ADD

                Spacer()

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
            .zIndex(1)          // ← ADD
        }
    }
    
    
    // original
    @ViewBuilder
    var backView2: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.widgetBackground)
                .padding(-20)

            // Full-size flip target behind controls; buttons above will intercept their areas
            Button(intent: FlipCardIntent()) {
                Color.clear
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

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

//            // Tap anywhere in the remaining area (excluding side button columns) to flip
//            Button(intent: FlipCardIntent()) {
//                Color.clear
//            }
//            .buttonStyle(.plain)
//            .contentShape(Rectangle())
//            .padding(.horizontal, 88) // exclude approx width of side controls + spacing
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
                    .widgetURL(nil)
            } else {
                KartangoWidgetEntryView(entry: entry)
                    .padding()
                    .background()
                    .widgetURL(nil)
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


