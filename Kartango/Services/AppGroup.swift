import Foundation

enum AppGroup {
    static let identifier = "group.com.ske.kartango"
    static let audioDirectoryName = "ImportedAudio"
    static let queueStateKey = "queueState"
    static let isFlippedKey = "isFlipped"
}

struct QueueCard: Codable, Equatable, Identifiable {
    let id: String
    let deckID: String
    let word: String
    let reading: String
    let meaning: String
    let audioFileName: String?
}

struct QueueState: Codable, Equatable {
    var queueDate: String = ""
    var cards: [QueueCard] = []
    var completedCardIDs: [String] = []
    var againCounts: [String: Int] = [:]

    var currentCard: QueueCard? {
        cards.first
    }
}

enum QueueStore {
    static func load(from defaults: UserDefaults? = UserDefaults(suiteName: AppGroup.identifier)) -> QueueState {
        guard
            let defaults,
            let data = defaults.data(forKey: AppGroup.queueStateKey),
            let state = try? JSONDecoder().decode(QueueState.self, from: data)
        else {
            return QueueState()
        }

        return state
    }

    static func save(_ state: QueueState, to defaults: UserDefaults? = UserDefaults(suiteName: AppGroup.identifier)) {
        guard let defaults, let data = try? JSONEncoder().encode(state) else {
            return
        }

        defaults.set(data, forKey: AppGroup.queueStateKey)
        defaults.set(false, forKey: AppGroup.isFlippedKey)
    }
}
