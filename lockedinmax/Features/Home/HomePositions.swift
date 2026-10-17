import SwiftUI

struct HomePositions: View {
    let positions: [Analytics.Position]
    let activityBuckets: [UUID: [Analytics.ChartPoint]]
    let activities: [Activity]

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
                    if let activity = activities.first(where: { $0.id == position.id }) {
                        NavigationLink {
                            ActivityDetailView(activityID: activity.id)
                        } label: {
                            row(position)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PositionRowButtonStyle())
                        .sensoryFeedback(.impact(weight: .light), trigger: activity.id)
                    } else {
                        row(position)
                    }
                    if position.id != positions.last?.id {
                        Rectangle().fill(Theme.hairline).frame(height: Theme.borderWidth)
                    }
                }
            }
        }
    }

    private func row(_ position: Analytics.Position) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle().fill(Theme.activityColor(position.colorHex)).frame(width: 36, height: 36)
                Image(systemName: position.iconName).typography(.rowTitle).foregroundStyle(Theme.onAccent)
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(position.name).typography(.rowTitle).foregroundStyle(Theme.textPrimary)
                Text(Formatters.hours(position.hours)).typography(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: Theme.Spacing.sm)
            Sparkline(values: downsampled(position.id),
                      color: (position.deltaHours ?? 0) >= 0 ? Theme.up : Theme.down)
            if let delta = position.deltaHours {
                DeltaLabel(value: delta, text: Formatters.delta(hours: delta, percent: position.deltaPercent))
                    .minimumScaleFactor(0.75)
            }
        }
        .padding(.vertical, Theme.Spacing.md)
        .accessibilityElement(children: .combine)
    }

    private func downsampled(_ id: UUID) -> [Double] {
        let values = activityBuckets[id, default: []].map(\.value)
        guard values.count > 14 else { return values }
        return (0..<14).map { index in
            let sourceIndex = index * (values.count - 1) / 13
            return values[sourceIndex]
        }
    }
}

private struct PositionRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        HomePositions(positions: [
            Analytics.Position(id: UUID(), name: "Math", colorHex: "#CCFF00", iconName: "function",
                               hours: 12.5, deltaHours: 4.2, deltaPercent: 13.9)
        ], activityBuckets: [:], activities: [])
        .padding(Theme.Spacing.lg)
    }
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
