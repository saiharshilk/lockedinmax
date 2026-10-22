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
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(position.name).typography(.rowTitle).foregroundStyle(Theme.textPrimary)
                    .lineLimit(1).truncationMode(.tail)
                Text(Formatters.hours(position.hours)).typography(.caption).foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Sparkline(values: downsampled(position.id),
                      color: (position.deltaHours ?? 0) >= 0 ? Theme.up : Theme.down,
                      size: CGSize(width: 56, height: 22))
                .frame(width: 56, height: 22)
            VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                if let delta = position.deltaHours {
                    if abs(delta) < 0.005 {
                        Text("0.0 hrs").typography(.caption).foregroundStyle(Theme.textSecondary)
                            .lineLimit(1).minimumScaleFactor(0.65)
                    } else {
                        Text("\(delta > 0 ? "+" : "−")\(Formatters.hours(abs(delta)))").typography(.caption)
                            .lineLimit(1).minimumScaleFactor(0.65)
                        if let percent = position.deltaPercent {
                            Text(Formatters.percent(percent)).typography(.caption)
                                .lineLimit(1).minimumScaleFactor(0.65)
                        }
                    }
                } else {
                    Text("—").typography(.caption)
                }
            }
            .frame(width: 96, alignment: .trailing)
        }
        .frame(minHeight: 56)
        .padding(.vertical, Theme.Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(position.name), \(Formatters.hours(position.hours))\(position.deltaHours.map { abs($0) < 0.005 ? ", unchanged" : ", \($0 > 0 ? "up" : "down") \(Formatters.hours(abs($0))) versus previous period" } ?? "")")
    }

    private func downsampled(_ id: UUID) -> [Double] {
        let rawValues = activityBuckets[id, default: []].map(\.value)
        guard rawValues.contains(where: { $0 > 0 }) else { return [0, 0] }
        let values = rawValues
        guard values.count > 14 else { return values }
        return (0..<14).map { index in
            let sourceIndex = index * (values.count - 1) / 13
            return values[sourceIndex]
        }
    }
}

private struct PositionRowButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
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
