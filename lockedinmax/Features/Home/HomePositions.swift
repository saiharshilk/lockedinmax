import SwiftUI

struct HomePositions: View {
    let positions: [Analytics.Position]

    var body: some View {
        SectionHeader(title: "POSITIONS")
        if positions.isEmpty {
            Text("No hours in this window.")
                .typography(.caption)
                .foregroundStyle(Theme.textSecondary)
                .padding(.vertical, Theme.Spacing.sm)
        } else {
            VStack(spacing: 0) {
                ForEach(positions) { position in
                    row(position)
                    if position.id != positions.last?.id {
                        Rectangle()
                            .fill(Theme.hairline)
                            .frame(height: Theme.borderWidth)
                    }
                }
            }
        }
    }

    private func row(_ position: Analytics.Position) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Theme.activityColor(position.colorHex))
                    .frame(width: 36, height: 36)
                Image(systemName: position.iconName)
                    .typography(.rowTitle)
                    .foregroundStyle(Theme.onAccent)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(position.name)
                    .typography(.rowTitle)
                    .foregroundStyle(Theme.textPrimary)
                Text("\(position.hours.formatted(.number.precision(.fractionLength(0...1)))) hrs")
                    .typography(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: Theme.Spacing.md)

            if let delta = position.deltaHours {
                DeltaLabel(
                    value: delta,
                    text: Analytics.deltaText(hours: delta, percent: position.deltaPercent)
                )
            }
        }
        .padding(.vertical, Theme.Spacing.md)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
        HomePositions(positions: [
            Analytics.Position(
                id: UUID(), name: "Math", colorHex: "#CCFF00", iconName: "function",
                hours: 12.5, deltaHours: 4.2, deltaPercent: 13.9
            ),
            Analytics.Position(
                id: UUID(), name: "Chess", colorHex: "#63C7FF", iconName: "crown",
                hours: 4, deltaHours: nil, deltaPercent: nil
            )
        ])
    }
    .padding(Theme.Spacing.lg)
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
