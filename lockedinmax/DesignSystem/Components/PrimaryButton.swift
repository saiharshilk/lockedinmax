import SwiftUI

struct PrimaryButton: View {
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .typography(.rowTitle)
                .tracking(Typography.buttonTracking)
                .foregroundStyle(Theme.onAccent)
                .frame(maxWidth: .infinity)
                .frame(minHeight: Theme.minimumTapHeight)
                .padding(.vertical, Theme.Spacing.xs)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PrimaryButton(title: "PREVIEW BUTTON") {}
        .padding(Theme.Spacing.lg)
        .background(Theme.background)
        .preferredColorScheme(.dark)
}
