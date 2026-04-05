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
            meaning: "person"
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (CardEntry) -> ()) {
        completion(
            CardEntry(
                date: Date(),
                isFlipped: false,
                word: "人",
                reading: "ひと",
                meaning: "person"
            )
        )
    }
    
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<CardEntry>) -> ()) {
        let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard

        let isFlipped = defaults.bool(forKey: "isFlipped")
        let word = defaults.string(forKey: "word") ?? "—"
        let reading = defaults.string(forKey: "reading") ?? ""
        let meaning = defaults.string(forKey: "meaning") ?? ""

        let entry = CardEntry(
            date: Date(),
            isFlipped: isFlipped,
            word: word,
            reading: reading,
            meaning: meaning
        )

        completion(Timeline(entries: [entry], policy: .never))
    }
}




struct PlayAudioIntent: AppIntent {
    static var title: LocalizedStringResource = "Play Audio"

    func perform() async throws -> some IntentResult {
        // trigger audio here (App Group / shared state / etc.)
        return .result()
    }
}


func updateCardFromIndex(defaults: UserDefaults) {
    let index = defaults.integer(forKey: "currentIndex")
    let words = defaults.stringArray(forKey: "queueWords") ?? []
    let readings = defaults.stringArray(forKey: "queueReadings") ?? []
    let meanings = defaults.stringArray(forKey: "queueMeanings") ?? []

    guard index < words.count else {
        defaults.set("DONE", forKey: "word")
        defaults.set("", forKey: "reading")
        defaults.set("", forKey: "meaning")
        return
    }

    defaults.set(words[index], forKey: "word")
    defaults.set(readings[index], forKey: "reading")
    defaults.set(meanings[index], forKey: "meaning")
}

// Flip
struct FlipCardIntent: AppIntent {
    static var title: LocalizedStringResource = "Flip Card"

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
        let current = defaults.bool(forKey: "isFlipped")
        defaults.set(!current, forKey: "isFlipped")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// Again
struct AgainIntent: AppIntent {
    static var title: LocalizedStringResource = "Again"

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard

        // record action (optional but ready)
        let cardID = defaults.string(forKey: "currentCardID") ?? ""
        defaults.set(cardID, forKey: "lastActionCardID")
        defaults.set("again", forKey: "lastActionType")

        // move index
        var index = defaults.integer(forKey: "currentIndex")
        index += 1
        defaults.set(index, forKey: "currentIndex")
        updateCardFromIndex(defaults: defaults)

        defaults.set(false, forKey: "isFlipped")
        defaults.set(Date().timeIntervalSince1970, forKey: "debug")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// Pass
struct PassIntent: AppIntent {
    static var title: LocalizedStringResource = "Pass"

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard

        let cardID = defaults.string(forKey: "currentCardID") ?? ""
        defaults.set(cardID, forKey: "lastActionCardID")
        defaults.set("pass", forKey: "lastActionType")

        var index = defaults.integer(forKey: "currentIndex")
        index += 1
        defaults.set(index, forKey: "currentIndex")
        updateCardFromIndex(defaults: defaults)

        defaults.set(false, forKey: "isFlipped")
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
    }

    // FRONT VIEW
    @ViewBuilder
    var frontView: some View {
        Button(intent: FlipCardIntent()) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.widgetBackground)
                    .padding(-20)

                if entry.word == "DONE" {
                    Label("All done for today!!", systemImage: "checkmark.circle.fill")
                        .font(.headline)
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
                    Text(entry.word).font(.title2).bold()
                    Text(entry.reading).font(.caption).foregroundColor(.gray)
                    Text(entry.meaning).font(.body)
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
        meaning: "person"
    )
    CardEntry(
        date: .now,
        isFlipped: true,
        word: "human",
        reading: "kon",
        meaning: "person"
    )
}

