import SwiftUI

struct ComingSoonView: View {
    let title: String

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text(title)
                .typography(.title)
                .foregroundStyle(Theme.textPrimary)
            Text("Coming soon")
                .typography(.body)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }
}

#Preview {
    ComingSoonView(title: "Stats").preferredColorScheme(.dark)
}
