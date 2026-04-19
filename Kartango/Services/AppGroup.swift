import Foundation

enum AppGroup {
    static let identifier = "group.com.mink.kartango"
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
    var reviewedCardIDs: [String] = []
    var againCounts: [String: Int] = [:]

    var currentCard: QueueCard? {
        cards.first
    }

    init(
        queueDate: String = "",
        cards: [QueueCard] = [],
        completedCardIDs: [String] = [],
        reviewedCardIDs: [String] = [],
        againCounts: [String: Int] = [:]
    ) {
        self.queueDate = queueDate
        self.cards = cards
        self.completedCardIDs = completedCardIDs
        self.reviewedCardIDs = reviewedCardIDs
        self.againCounts = againCounts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        queueDate = try container.decodeIfPresent(String.self, forKey: .queueDate) ?? ""
        cards = try container.decodeIfPresent([QueueCard].self, forKey: .cards) ?? []
        completedCardIDs = try container.decodeIfPresent([String].self, forKey: .completedCardIDs) ?? []
        reviewedCardIDs = try container.decodeIfPresent([String].self, forKey: .reviewedCardIDs) ?? []
        againCounts = try container.decodeIfPresent([String: Int].self, forKey: .againCounts) ?? [:]
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
