import Foundation
import BackgroundTasks
import WidgetKit

enum BackgroundRefresh {
    // Update this identifier in Info.plist under BGTaskSchedulerPermittedIdentifiers
    // and ensure it matches exactly.
    static let identifier = "com.ske.kartango.refresh"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            handle(task: task as! BGAppRefreshTask)
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)

        #if DEBUG
        // During development, schedule ~10 seconds from now so you can test quickly.
        request.earliestBeginDate = Date(timeIntervalSinceNow: 10)
        #else
        // Aim for shortly after midnight; the system chooses the actual run time.
        if let next = Calendar.current.date(bySettingHour: 0, minute: 10, second: 0, of: Date().addingTimeInterval(86400)) {
            request.earliestBeginDate = next
        }
        #endif

        do {
            try BGTaskScheduler.shared.submit(request)
            #if DEBUG
            print("[BGTask] Submitted app refresh with earliestBeginDate=\(String(describing: request.earliestBeginDate))")
            #endif
        } catch {
            print("[BGTask] Failed to schedule app refresh: \(error)")
            #if DEBUG
            // Fallback: run the work immediately so you can test even if scheduling is not permitted (Code=1).
            DispatchQueue.global(qos: .utility).async {
                let success = rebuildQueueIfNeededAndReloadWidget()
                print("[BGTask][DEBUG] Ran fallback refresh immediately. Success=\(success)")
            }
            #endif
        }
    }

    static func handle(task: BGAppRefreshTask) {
        // Always schedule the next one
        schedule()

        task.expirationHandler = {
            // If we run out of time, complete and let the next cycle try again
            task.setTaskCompleted(success: false)
        }

        DispatchQueue.global(qos: .utility).async {
            let success = rebuildQueueIfNeededAndReloadWidget()
            task.setTaskCompleted(success: success)
        }
    }

    // MARK: - Work

    private static func rebuildQueueIfNeededAndReloadWidget() -> Bool {
        #if DEBUG
        print("[BGTask][DEBUG] Starting rebuildQueueIfNeededAndReloadWidget")
        print("[BGTask][DEBUG] AppGroup identifier=\(AppGroup.identifier)")
        let suiteDefaults = UserDefaults(suiteName: AppGroup.identifier)
        print("[BGTask][DEBUG] suiteDefaults available=\(suiteDefaults != nil)")
        let fm = FileManager.default
        let containerURL = fm.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)
        print("[BGTask][DEBUG] containerURL=\(String(describing: containerURL))")
        #endif
        
        let defaults: UserDefaults
        if let suite = UserDefaults(suiteName: AppGroup.identifier) {
            defaults = suite
            #if DEBUG
            print("[BGTask][DEBUG] Using App Group UserDefaults")
            #endif
        } else {
            defaults = .standard
            #if DEBUG
            print("[BGTask][DEBUG] Falling back to .standard UserDefaults (App Group unavailable)")
            #endif
        }

        var state = QueueStore.load(from: defaults)
        #if DEBUG
        print("[BGTask][DEBUG] Loaded QueueState: queueDate=\(state.queueDate), completed=\(state.completedCardIDs.count), reviewed=\(state.reviewedCardIDs.count)")
        #endif

        let data = defaults.data(forKey: "allLibraryCards") ?? Data()
        #if DEBUG
        print("[BGTask][DEBUG] allLibraryCards raw data bytes=\(data.count)")
        #endif

        let allCards: [QueueCard]
        do {
            allCards = try JSONDecoder().decode([QueueCard].self, from: data)
        } catch {
            #if DEBUG
            print("[BGTask][DEBUG] Failed to decode allLibraryCards: \(error)")
            #endif
            allCards = []
        }

        let todayKey = queueDateKey(for: Date())
        #if DEBUG
        print("[BGTask][DEBUG] todayKey=\(todayKey) state.queueDate=\(state.queueDate) allCards.count=\(allCards.count)")
        #endif

        guard state.queueDate != todayKey else {
            #if DEBUG
            print("[BGTask][DEBUG] Queue already up to date for today; skipping rebuild.")
            #endif
            return true // nothing to do
        }

        let rebuiltCards = buildDailyQueue(
            from: allCards,
            reviewedCardIDs: state.reviewedCardIDs,
            againCounts: state.againCounts,
            defaults: defaults
        )
        #if DEBUG
        print("[BGTask][DEBUG] Rebuilt queue: rebuiltCards.count=\(rebuiltCards.count)")
        #endif

        state = QueueState(
            queueDate: todayKey,
            cards: rebuiltCards,
            completedCardIDs: [],
            reviewedCardIDs: state.reviewedCardIDs,
            againCounts: state.againCounts
        )
        QueueStore.save(state, to: defaults)
        #if DEBUG
        print("[BGTask][DEBUG] Saved new QueueState for date=\(todayKey) queueCount=\(state.cards.count)")
        #endif

        #if DEBUG
        print("[BGTask][DEBUG] Requesting widget timeline reload for kind=KartangoWidget")
        #endif
        // Nudge the widget to refresh its timeline
        WidgetCenter.shared.reloadTimelines(ofKind: "KartangoWidget")
        return true
    }

    // MARK: - Queue logic (duplicated here to avoid cross-target dependencies)

    private static func buildDailyQueue(
        from cards: [QueueCard],
        reviewedCardIDs: [String],
        againCounts: [String: Int],
        defaults: UserDefaults?
    ) -> [QueueCard] {
        let newCardsPerDay = normalizedDailyLimit(
            defaults?.integer(forKey: "newCardsPerDay") ?? 10
        )

        let reviewCardsPerDay = normalizedDailyLimit(
            defaults?.integer(forKey: "reviewCardsPerDay") ?? 10
        )

        let reviewedSet = Set(reviewedCardIDs)

        let reviewCards = cards.filter { reviewedSet.contains($0.id) }
        let newCards = cards.filter { !reviewedSet.contains($0.id) }

        let selectedReviewCards = weightedReviewSelection(
            from: reviewCards,
            againCounts: againCounts,
            limit: reviewCardsPerDay
        )

        let selectedReviewIDs = Set(selectedReviewCards.map { $0.id })

        let selectedNewCards = Array(
            newCards
                .filter { !selectedReviewIDs.contains($0.id) }
                .prefix(newCardsPerDay)
        )

        return selectedReviewCards + selectedNewCards
    }

    private static func weightedReviewSelection(
        from reviewCards: [QueueCard],
        againCounts: [String: Int],
        limit: Int
    ) -> [QueueCard] {
        guard reviewCards.count > limit else { return reviewCards }

        var generator = SystemRandomNumberGenerator()
        var remainingCards = reviewCards
        var selectedCards: [QueueCard] = []

        while selectedCards.count < limit, !remainingCards.isEmpty {
            let totalWeight = remainingCards.reduce(0) {
                $0 + max(1, againCounts[$1.id, default: 0] + 1)
            }

            var randomWeight = Int.random(in: 0..<totalWeight, using: &generator)

            for (index, card) in remainingCards.enumerated() {
                randomWeight -= max(1, againCounts[card.id, default: 0] + 1)

                if randomWeight < 0 {
                    selectedCards.append(card)
                    remainingCards.remove(at: index)
                    break
                }
            }
        }

        return selectedCards
    }

    private static func normalizedDailyLimit(_ value: Int) -> Int {
        let allowedValues = [10, 20, 30, 40, 50]
        return allowedValues.contains(value) ? value : 10
    }

    private static func queueDateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
