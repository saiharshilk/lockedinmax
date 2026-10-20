import SwiftUI

struct LogSegmentControl: View {
    @Binding var isScore: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            segment("Session", score: false)
            segment("Score", score: true)
        }
        .padding(Theme.Spacing.xs)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
    }

    private func segment(_ title: String, score: Bool) -> some View {
        Button { isScore = score } label: {
            Text(title)
                .typography(.rowTitle)
                .foregroundStyle(isScore == score ? Theme.onAccent : Theme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: Theme.minimumTapHeight)
                .background(isScore == score ? Theme.accent : Theme.surface,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.small))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isScore == score ? .isSelected : [])
    }
}

#Preview {
    LogSegmentControl(isScore: .constant(false))
        .padding(Theme.Spacing.lg).background(Theme.background)
}
