import SwiftUI

struct StatsView: View {
    let deckCount: Int
    let totalCardCount: Int
    let queueState: QueueState
    let onRebuildTodayQueue: () -> Void
    let onSimulateTomorrowQueue: () -> Void

    @AppStorage("newCardsPerDay", store: UserDefaults(suiteName: AppGroup.identifier))
    private var newCardsPerDay = 10

    @AppStorage("reviewCardsPerDay", store: UserDefaults(suiteName: AppGroup.identifier))
    private var reviewCardsPerDay = 10

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brightBeige
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        streakSection
                        dailyTrendSection
                        wordsLearnedSection
                        againPassSection
                        debugSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 140)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Streak

    private var streakSection: some View {
        VStack(spacing: 14) {
            Text("\(streakCount)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(Color.gold)

            Text("day streak")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 18) {
                ForEach(0..<5) { index in
                    let dayOffset = index - 2
                    let isToday = dayOffset == 0
                    let isFuture = dayOffset > 0

                    Image(systemName: "star.fill")
                        .font(.system(size: isToday ? 28 : 18))
                        .foregroundStyle(isFuture ? Color.defaultGray.opacity(0.3) : Color.gold)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Daily Trend

    private var dailyTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Trend")
                .font(.headline)
                .foregroundStyle(.black.opacity(0.85))

            DailyTrendChart(data: dailyTrendData)
                .frame(height: 140)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Words Learned (Donut)

    private var wordsLearnedSection: some View {
        VStack(spacing: 16) {
            Text("Words Learned")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            DonutChart(
                progress: wordsLearnedProgress,
                centerValue: "\(totalWordsReviewed)",
                centerLabel: "words reviewed",
                secondaryLabel: "from \(wordsGoal)"
            )
            .frame(height: 180)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Again / Pass

    private var againPassSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Again / Pass Rate")
                .font(.headline)
                .foregroundStyle(.black.opacity(0.85))

            AgainPassBar(againPercent: againRate)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Debug (collapsed at bottom)

    private var debugSection: some View {
        DisclosureGroup("Debug Info") {
            VStack(alignment: .leading, spacing: 8) {
                debugRow(title: "Queue date", value: queueState.queueDate.isEmpty ? "none" : queueState.queueDate)
                debugRow(title: "Current queue", value: "\(queueState.cards.count)")
                debugRow(title: "Remaining review", value: "\(remainingReviewCount)")
                debugRow(title: "Remaining new", value: "\(remainingNewCount)")
                debugRow(title: "Reviewed pool", value: "\(queueState.reviewedCardIDs.count)")
                debugRow(title: "Again counts", value: "\(queueState.againCounts.count)")
                debugRow(title: "Completed today", value: "\(queueState.completedCardIDs.count)")
                debugRow(title: "Daily new limit", value: "\(newCardsPerDay)")
                debugRow(title: "Daily review limit", value: "\(reviewCardsPerDay)")

                Button(action: onRebuildTodayQueue) {
                    Text("Rebuild Today's Queue")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.deckAccent, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)

                Button(action: onSimulateTomorrowQueue) {
                    Text("Simulate Tomorrow Queue")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.deckAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.deckAccent, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Real Data

    private var streakCount: Int {
        DailyStatsStore.streak()
    }

    private var dailyTrendData: [Double] {
        DailyStatsStore.dailyTrendData(days: 10).map { Double($0.count) }
    }

    private var totalWordsReviewed: Int {
        DailyStatsStore.load().dailyReviewCounts.values.reduce(0, +)
    }

    private var wordsGoal: Int {
        let rounded = ((totalWordsReviewed / 1000) + 1) * 1000
        return max(rounded, 2000)
    }

    private var wordsLearnedProgress: Double {
        guard wordsGoal > 0 else { return 0 }
        return min(Double(totalWordsReviewed) / Double(wordsGoal), 1.0)
    }

    private var againRate: Double {
        DailyStatsStore.againRate()
    }

    private var remainingReviewCount: Int {
        let reviewedCardIDs = Set(queueState.reviewedCardIDs)
        return queueState.cards.filter { reviewedCardIDs.contains($0.id) }.count
    }

    private var remainingNewCount: Int {
        let reviewedCardIDs = Set(queueState.reviewedCardIDs)
        return queueState.cards.filter { !reviewedCardIDs.contains($0.id) }.count
    }

    private func debugRow(title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.black.opacity(0.8))
            Spacer(minLength: 12)
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(Color.deckAccent)
        }
    }
}

// MARK: - Gold Color

extension Color {
    static let gold = Color(red: 0.95, green: 0.75, blue: 0.2)
}
