import SwiftUI

struct HomeSummaryView: View {
    let summary: Analytics.Summary
    let range: TimeRange
    let point: Analytics.ChartPoint?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(label)
                .typography(.sectionLabel)
                .foregroundStyle(point == nil ? Theme.textTertiary : Theme.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                Text(Formatters.hoursValue(value))
                    .typography(.heroNumber)
                    .foregroundStyle(Theme.textPrimary)
                Text(Formatters.hoursUnit(value)).typography(.body).foregroundStyle(Theme.textSecondary)
            }

            if point == nil, range != .all, let delta = summary.deltaHours {
                DeltaLabel(
                    value: delta,
                    text: "\(Formatters.delta(hours: delta, percent: summary.deltaPercent)) vs previous"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityValue(Formatters.hours(value))
    }

    private var value: Double { point?.value ?? summary.currentHours }

    private var accessibilitySummary: String {
        guard point == nil, let delta = summary.deltaHours else {
            return "\(Formatters.hours(value)), selected chart point"
        }
        guard abs(delta) >= 0.005 else { return "\(Formatters.hours(value)), time invested, unchanged" }
        return "\(Formatters.hours(value)), \(delta > 0 ? "up" : "down") \(Formatters.hours(abs(delta))) versus previous period"
    }

    private var label: String {
        if let point {
            return point.date
                .formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
                .uppercased()
        }
        return "TIME INVESTED · \(range.displayName)"
    }
}

#Preview {
    HomeSummaryView(
        summary: Analytics.summarize(sessions: [], range: .week),
        range: .week,
        point: nil
    )
    .padding(Theme.Spacing.lg)
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
