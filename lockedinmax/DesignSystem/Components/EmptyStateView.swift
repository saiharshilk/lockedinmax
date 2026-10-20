import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text(title)
                .typography(.title)
                .foregroundStyle(Theme.textPrimary)
            if !message.isEmpty {
                Text(message)
                    .typography(.body)
                    .foregroundStyle(Theme.textSecondary)
            }
            if !buttonTitle.isEmpty {
                PrimaryButton(title: buttonTitle, action: action)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard()
    }
}
