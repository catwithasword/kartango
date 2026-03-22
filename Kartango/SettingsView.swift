import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brightBeige
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    Text("Settings")
                        .font(.title2.weight(.semibold))

                    Text("App Group audio sharing is enabled for imported deck audio.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(24)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 140)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
