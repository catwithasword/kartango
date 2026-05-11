import Foundation

struct DailyStats: Codable {
    var reviewDates: Set<String> = []          // "yyyy-MM-dd" strings
    var dailyReviewCounts: [String: Int] = [:] // date → cards reviewed that day
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
        let today = Self.todayKey()

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
            let key = Self.dateKey(for: date)
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
            let key = Self.dateKey(for: date)
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

    static func wordsLearned() -> Int {
        let stats = load()
        return stats.reviewDates.count > 0
            ? stats.dailyReviewCounts.values.reduce(0, +)
            : 0
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
