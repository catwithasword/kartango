import SwiftUI

struct SettingsView: View {
    private enum SettingField {
        case newCards
        case reviewCards

        var title: String {
            switch self {
            case .newCards:
                "New cards per day"
            case .reviewCards:
                "Review cards per day"
            }
        }
    }

    @AppStorage("newCardsPerDay", store: UserDefaults(suiteName: AppGroup.identifier))
    private var newCardsPerDay = 10

    @AppStorage("reviewCardsPerDay", store: UserDefaults(suiteName: AppGroup.identifier))
    private var reviewCardsPerDay = 10

    private let allowedValues = [10, 20, 30, 40, 50]
    @State private var pendingField: SettingField?
    @State private var pendingValue = 10
    @State private var isChangeAlertPresented = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brightBeige
                    .ignoresSafeArea()

                List {
                    Section("Settings") {
                        settingsRow(
                            title: "New cards per day",
                            selection: Binding(
                                get: { newCardsPerDay },
                                set: { stageChange(for: .newCards, value: $0) }
                            )
                        )
                        settingsRow(
                            title: "Review cards per day",
                            selection: Binding(
                                get: { reviewCardsPerDay },
                                set: { stageChange(for: .reviewCards, value: $0) }
                            )
                        )
                    }
                }
                .scrollContentBackground(.hidden)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 140)
                }

                if isChangeAlertPresented {
                    Color.black.opacity(0.18)
                        .ignoresSafeArea()

                    confirmationCard
                        .padding(.horizontal, 26)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear(perform: normalizeStoredValues)
    }

    private func settingsRow(title: String, selection: Binding<Int>) -> some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.black.opacity(0.8))

            Spacer(minLength: 12)

            Picker(title, selection: selection) {
                ForEach(allowedValues, id: \.self) { value in
                    Text("\(value)")
                        .tag(value)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(.black.opacity(0.8))
            .frame(width: 54, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.defaultGray.opacity(0.55))
            )
        }
        .listRowBackground(Color.deckCard)
    }

    private var confirmationCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Apply tomorrow?")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.black.opacity(0.9))

            Text("This change will apply to tomorrow's queue, not today's remaining cards.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Cancel", action: clearPendingChange)
                    .font(.headline)
                    .foregroundStyle(.black.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.defaultGray.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))

                Button("Accept", action: applyPendingChange)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(22)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 6)
    }

    private func normalizeStoredValues() {
        if !allowedValues.contains(newCardsPerDay) {
            newCardsPerDay = 10
        }

        if !allowedValues.contains(reviewCardsPerDay) {
            reviewCardsPerDay = 10
        }
    }

    private func stageChange(for field: SettingField, value: Int) {
        guard allowedValues.contains(value) else {
            return
        }

        let currentValue: Int
        switch field {
        case .newCards:
            currentValue = newCardsPerDay
        case .reviewCards:
            currentValue = reviewCardsPerDay
        }

        guard value != currentValue else {
            return
        }

        pendingField = field
        pendingValue = value
        isChangeAlertPresented = true
    }

    private func applyPendingChange() {
        guard let pendingField else {
            return
        }

        switch pendingField {
        case .newCards:
            newCardsPerDay = pendingValue
        case .reviewCards:
            reviewCardsPerDay = pendingValue
        }

        clearPendingChange()
    }

    private func clearPendingChange() {
        isChangeAlertPresented = false
        pendingField = nil
        pendingValue = 10
    }
}
