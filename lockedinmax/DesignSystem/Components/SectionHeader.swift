import SwiftUI

struct SectionHeader: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(title)
                .typography(.sectionLabel)
                .foregroundStyle(Theme.textTertiary)
                .accessibilityAddTraits(.isHeader)
            Rectangle()
                .fill(Theme.hairline)
                .frame(height: Theme.borderWidth)
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    SectionHeader(title: "Positions")
        .padding(Theme.Spacing.lg)
        .background(Theme.background)
        .preferredColorScheme(.dark)
}
