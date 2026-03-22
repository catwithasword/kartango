# Kartango

A flashcard learning app for iOS that surfaces vocabulary cards directly on the home screen via a WidgetKit widget — no need to open the app. Users import `.apkg` decks (Anki format), configure daily goals, and review cards using a simplified Again/Pass system.

## Platform & Requirements

- **iOS 17+** (required for interactive widgets)
- **Swift 5.9+**, SwiftUI
- Two targets: `Kartango` (main app) + `KartangoWidget` (WidgetKit extension)

## Architecture

MVVM throughout.

- **Models/** — plain data structs/Core Data entities: `Card`, `Deck`, `DailyQueue`, `Settings`, `Statistics`
- **ViewModels/** — `@Observable` classes: `QueueEngine`, `DeckImporter`, `AudioPlayer`
- **Views/** — SwiftUI screens: `Home`, `DeckManager`, `Stats`, `Settings`
- **Services/** — stateless logic: `APKGParser`, `AudioService`, `StatisticsCalculator`
- **Resources/** — asset catalog, Core Data `.xcdatamodeld`
- **KartangoWidget/** — `KartangoWidget.swift` entry point, `WidgetViews/` for widget UI

## Key Dependencies (Swift Package Manager)

| Package | Purpose |
|---|---|
| `ZIPFoundation` | Unzip `.apkg` files |
| `SQLite.swift` | Read Anki's SQLite DB inside `.apkg` |

System frameworks: `SwiftUI`, `WidgetKit`, `Core Data`, `AVFoundation`

## Core Components

**APKGParser** (`Services/APKGParser.swift`)
Unzips `.apkg` → extracts `collection.anki2` (SQLite) for cards + `media` JSON for audio mapping. Cards have: word, definition, optional example, optional audio filename.

**QueueEngine** (`ViewModels/QueueEngine.swift`)
Builds the daily queue from active decks respecting the user's `newCardsPerDay` / `reviewCardsPerDay` settings. Cards with more "Again" history in their history are prioritised earlier the next day.

**Widget State Manager** (inside `KartangoWidget/`)
Shares queue state between app and widget via `App Group` (`UserDefaults(suiteName:)`). Persists current card index and flip state so progress survives widget reloads.

**AudioService** (`Services/AudioService.swift`)
`AVAudioPlayer`-based playback. Audio files are stored in the app's shared container so the widget can trigger playback via `AppIntent`.

**StatisticsCalculator** (`Services/StatisticsCalculator.swift`)
Derives: total words learned, again rate, daily trend, study streak — all computed from Core Data card history.

## Widget Details

- Built with **WidgetKit** + **AppIntents** (required for interactive buttons in iOS 17)
- Widget displays one card at a time; supports tap-to-flip and Again/Pass buttons
- Swipe between cards via `Button` intents (direct gesture not available in widgets)
- App Group identifier must be consistent across both targets in Signing & Capabilities

## Spaced Repetition Logic

Simplified two-outcome system (not SM-2):
- **Pass** → card is done for today
- **Again** → card re-enters today's queue at the back
- Tomorrow's queue order is influenced by cumulative Again count per card (higher = earlier)

## Data Storage

- Core Data for cards, decks, and review history (local only, no iCloud sync)
- `App Group` shared `UserDefaults` for widget ↔ app state
- Imported audio files stored in app's shared container directory

## Out of Scope

Do not add or suggest: deck creation inside the app, cross-device/iCloud sync, social/shared decks, image flashcards, custom card templates, or TTS. These are explicitly out of scope.

## Code Conventions

- Use `@Observable` macro (Swift 5.9) for ViewModels — not `ObservableObject`
- Async/await for all async work (no Combine)
- `camelCase` for Swift identifiers; `snake_case` only for JSON/SQLite column names
- One SwiftUI `View` per file, named to match the file
- Services are stateless structs or actors where concurrency is needed

## Running the Project

Open `Kartango.xcworkspace`. No API keys or external config needed. Ensure both the `Kartango` and `KartangoWidget` targets share the same App Group capability before running on a real device (widgets require a physical device or simulator with home screen support).
