# Kartango

A flashcard learning app for iOS that surfaces vocabulary cards directly on your home screen via a WidgetKit widget. Import Anki decks, set daily goals, and review cards without even opening the app.

## Features

- **Home Screen Widget** — One card at a time on your home screen with tap-to-flip and Again/Pass buttons. No need to open the app to study.
- **Anki Import** — Drop in `.apkg` files and Kartango parses the deck, media, and card structure automatically.
- **Simplified Review** — Pass (done for today) or Again (re-queued). Cards you struggle with come back sooner.
- **Daily Goals** — Configure how many new and review cards you want per day.
- **Stats Dashboard** — Track words learned, again rate, daily trends, and study streaks with built-in charts.

## Requirements

- iOS 17+ (interactive widgets)
- Xcode 15+ / Swift 5.9+

## Project Structure

```
Kartango/
├── KartangoApp.swift          # App entry point
├── ContentView.swift          # Root tab navigation
├── CustomTabBar.swift         # Custom tab bar
├── Theme.swift                # Colors and styling
├── Persistence.swift          # Core Data stack
│
├── Models/
│   ├── Card+CoreDataClass.swift
│   ├── Card+CoreDataProperties.swift
│   ├── Deck+CoreDataClass.swift
│   └── Deck+CoreDataProperties.swift
│
├── ViewModels/
│   └── DeckImporter.swift     # .apkg import logic
│
├── Views/
│   └── Charts/
│       ├── DailyTrendChart.swift
│       ├── AgainPassBar.swift
│       └── DonutChart.swift
│
├── Services/
│   ├── APKGParser.swift       # Unzip + SQLite parsing
│   ├── AppGroup.swift         # App Group shared container
│   └── DailyStatsStore.swift  # Stats persistence
│
├── StatsView.swift            # Statistics screen
├── SettingsView.swift         # Settings screen
├── DecksView.swift            # Deck list / manager
└── DeckRowView.swift          # Individual deck row
│
KartangoWidget/
├── KartangoWidget.swift       # Widget entry point
├── KartangoWidgetBundle.swift
├── AppGroup.swift             # Shared App Group access
└── WidgetColors.swift         # Widget theme
```

## Dependencies

| Package | Purpose |
|---------|---------|
| [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) | Unzip `.apkg` archives |
| [SQLite.swift](https://github.com/nicklama/SQLite.swift) | Read Anki's SQLite database |

## Architecture

**MVVM** with `@Observable` ViewModels, async/await throughout (no Combine).

- **Core Data** stores cards, decks, and review history (local only)
- **App Group** shared `UserDefaults` keeps widget and app in sync
- **WidgetKit + AppIntents** powers interactive widget buttons (iOS 17)

## How It Works

1. Import one or more `.apkg` files from the deck manager
2. Set your daily new/review card targets in Settings
3. The home screen widget shows the next card from your daily queue
4. Tap to flip, then **Pass** or **Again** — that's it
5. Cards answered "Again" re-enter today's queue; tomorrow they appear earlier based on how many times you've missed them

## Getting Started

1. Open `Kartango.xcworkspace` in Xcode
2. Make sure both the `Kartango` and `KartangoWidget` targets share the same **App Group** capability (Signing & Capabilities)
3. Build and run on a device (widgets require a physical device or simulator with home screen support)

## License

TBD
