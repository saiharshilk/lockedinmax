import SwiftUI

struct HomeEmptyState: View {
    let onLog: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text("Nothing on the board.")
                .typography(.title)
                .foregroundStyle(Theme.textPrimary)
            Text("Log your first session to open your position.")
                .typography(.body)
                .foregroundStyle(Theme.textSecondary)
            PrimaryButton(title: "LOG A SESSION", action: onLog)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard()
    }
}

#Preview {
    HomeEmptyState(onLog: {})
        .padding(Theme.Spacing.lg)
        .background(Theme.background)
        .preferredColorScheme(.dark)
}
