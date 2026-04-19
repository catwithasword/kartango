//
//  AppGroup.swift
//  Kartango
//
//  Created by Mink on 5/4/2569 BE.
//
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

// MARK: - Daily Stats

struct DailyStats: Codable {
    var reviewDates: Set<String> = []
    var dailyReviewCounts: [String: Int] = [:]
    var totalAgainCount: Int = 0
    var totalPassCount: Int = 0
}

enum DailyStatsStore {
    private static let key = "dailyStats"

    static func load(from defaults: UserDefaults? = UserDefaults(suiteName: AppGroup.identifier)) -> DailyStats {
        guard
            let defaults,
            let data = defaults.data(forKey: key),
            let stats = try? JSONDecoder().decode(DailyStats.self, from: data)
        else {
            return DailyStats()
        }
        return stats
    }

    static func save(_ stats: DailyStats, to defaults: UserDefaults? = UserDefaults(suiteName: AppGroup.identifier)) {
        guard let defaults, let data = try? JSONEncoder().encode(stats) else { return }
        defaults.set(data, forKey: key)
    }

    static func recordReview(isAgain: Bool, to defaults: UserDefaults? = UserDefaults(suiteName: AppGroup.identifier)) {
        var stats = load(from: defaults)
        let today = todayKey()

        stats.reviewDates.insert(today)
        stats.dailyReviewCounts[today, default: 0] += 1

        if isAgain {
            stats.totalAgainCount += 1
        } else {
            stats.totalPassCount += 1
        }

        save(stats, to: defaults)
    }

    static func streak() -> Int {
        let stats = load()
        var count = 0
        var date = Date()

        while true {
            let key = dateKey(for: date)
            guard stats.reviewDates.contains(key) else { break }
            count += 1
            guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: date) else { break }
            date = prev
        }
        return count
    }

    static func dailyTrendData(days: Int = 10) -> [(date: String, count: Int)] {
        let stats = load()
        var result: [(String, Int)] = []

        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let key = dateKey(for: date)
            result.append((key, stats.dailyReviewCounts[key] ?? 0))
        }
        return result
    }

    static func againRate() -> Double {
        let stats = load()
        let total = stats.totalAgainCount + stats.totalPassCount
        guard total > 0 else { return 0 }
        return Double(stats.totalAgainCount) / Double(total)
    }

    private static func todayKey() -> String {
        dateKey(for: Date())
    }

    private static func dateKey(for date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
