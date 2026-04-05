//
//  KartangoWidget.swift
//  KartangoWidget
//
//  Created by Panida Rumriankit on 15/3/2569 BE.
//

import WidgetKit
import SwiftUI
import AppIntents



// MARK: - Flip
struct FlipCardIntent: AppIntent {
    static var title: LocalizedStringResource = "Flip Card"
    
    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults.standard
        let current = defaults.bool(forKey: "isFlipped")
        defaults.set(!current, forKey: "isFlipped")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}


struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> CardEntry {
        CardEntry(date: Date(), isFlipped: false)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (CardEntry) -> ()) {
        completion(CardEntry(date: Date(), isFlipped: false))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<CardEntry>) -> ()) {
        let isFlipped = UserDefaults.standard.bool(forKey: "isFlipped")
        let entry = CardEntry(date: Date(), isFlipped: isFlipped)
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



struct AgainIntent: AppIntent {
    static var title: LocalizedStringResource = "Again"

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults.standard
        var index = defaults.integer(forKey: "currentIndex")

        index += 1 // still move forward
        defaults.set(index, forKey: "currentIndex")
        defaults.set(false, forKey: "isFlipped")

        // TODO: store "again" result

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct PassIntent: AppIntent {
    static var title: LocalizedStringResource = "Pass"

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults.standard
        var index = defaults.integer(forKey: "currentIndex")

        index += 1
        defaults.set(index, forKey: "currentIndex")
        defaults.set(false, forKey: "isFlipped")

        // TODO: store "pass"

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}


struct CardEntry: TimelineEntry {
    let date: Date
    let isFlipped: Bool
}

struct KartangoWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        ZStack {
            
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.widgetBackground)
                .padding(-20)
            Button(intent: FlipCardIntent()) {
                Color.clear
            }
            .buttonStyle(.plain)
            
            if entry.isFlipped {
                HStack {
                    // audio button
                    Button(intent: PlayAudioIntent()) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.audioButton)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    VStack(spacing: 6) {
                        Text("ひと")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("人")
                            .font(.system(size: 40, weight: .bold))
                        Text("person")
                            .font(.headline)
                    } // end VStack

                    Spacer()
                    
                    VStack(spacing: 12) {
                        // again button
                        Button(intent: AgainIntent()) {
                            Image(systemName: "arrow.uturn.left")
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.againButton)
                                .clipShape(Circle())
                               
                        }
                        .buttonStyle(.plain)

                        // pass button
                        Button(intent: PassIntent()) {
                            Image(systemName: "arrow.right")
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.passButton)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    } // end Vstack
                } // end HStack
                .padding()
            } else {
                
                    Text("人")
                        .font(.system(size: 50, weight: .bold))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .containerBackground(.clear, for: .widget)

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
    CardEntry(date: .now, isFlipped: false)
    CardEntry(date: .now, isFlipped: true)
}
