import SwiftUI

extension Color {
    static let brightBeige = Color(
        red: 1.0,
        green: 244.0 / 255.0,
        blue: 234.0 / 255.0
    )

    static let defaultGray = Color(
        red: 204.0 / 255.0,
        green: 204.0 / 255.0,
        blue: 204.0 / 255.0
    )

    static let deckAccent = Color(
        red: 116.0 / 255.0,
        green: 156.0 / 255.0,
        blue: 172.0 / 255.0
    )

    static let remainingAccent = Color(
        red: 145.0 / 255.0,
        green: 191.0 / 255.0,
        blue: 137.0 / 255.0
    )

    static let deckCard = Color.white.opacity(0.8)
}
