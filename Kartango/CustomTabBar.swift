import SwiftUI

enum AppTab {
    case decks
    case stats
    case settings

    var title: String {
        switch self {
        case .decks:
            "Decks"
        case .stats:
            "Stats"
        case .settings:
            "Settings"
        }
    }

    var selectedImageName: String {
        switch self {
        case .decks:
            "DecksWhite"
        case .stats:
            "Statswhite"
        case .settings:
            "SettingWhite"
        }
    }

    var unselectedImageName: String {
        switch self {
        case .decks:
            "DecksGray"
        case .stats:
            "StatsGray"
        case .settings:
            "SettingGray"
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab

    private let tabs: [AppTab] = [.decks, .stats, .settings]

    var body: some View {
        GeometryReader { geometry in
            let tabWidth = geometry.size.width / CGFloat(tabs.count)

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.white.opacity(0.94))
                    .frame(height: 80)
                    .shadow(color: .black.opacity(0.16), radius: 4, x: 0, y: 6)

                HStack(spacing: 0) {
                    ForEach(Array(tabs.enumerated()), id: \.offset) { _, tab in
                        tabButton(tab)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 76)

                selectedTabButton
                    .frame(width: tabWidth, height: 104)
                    .offset(x: selectedOffsetX(tabWidth: tabWidth))
            }
        }
        .frame(height: 108)
    }

    private func selectedOffsetX(tabWidth: CGFloat) -> CGFloat {
        guard let index = tabs.firstIndex(where: { $0 == selectedTab }) else {
            return 0
        }

        return CGFloat(index) * tabWidth
    }

    private func tabButton(_ tab: AppTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 5) {
                Image(tab.unselectedImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)

                Text(tab.title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(Color.defaultGray)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(selectedTab == tab ? 0 : 1)
        }
        .buttonStyle(.plain)
    }

    private var selectedTabButton: some View {
        Button {
            selectedTab = selectedTab
        } label: {
            VStack(spacing: 4) {
                Image(selectedTab.selectedImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)

                Text(selectedTab.title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(width: 84, height: 84)
            .background(
                Circle()
                    .fill(Color.deckAccent)
            )
            .shadow(color: .black.opacity(0.14), radius: 5, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}
