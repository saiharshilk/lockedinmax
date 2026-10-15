import SwiftUI

#if DEBUG
private struct MetricAnalyticsPreview: View {
    private let summary: StatsAnalytics.MetricSummary

    init() {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 12)) ?? .now
        let entries = [
            MetricEntry(date: now.addingTimeInterval(-3 * 86_400), value: 80),
            MetricEntry(date: now.addingTimeInterval(-2 * 86_400), value: 84),
            MetricEntry(date: now.addingTimeInterval(-86_400), value: 82),
            MetricEntry(date: now, value: 86)
        ]
        summary = StatsAnalytics.metricSummary(entries: entries, range: .week, now: now, calendar: calendar)
        assert(summary.latest?.value == 86)
        assert(summary.change == 6)
        assert(summary.best == 86)
        assert(summary.average == 83)
        assert(summary.entries.count == 4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("WEEKLY SCORE SAMPLE").typography(.sectionLabel).foregroundStyle(Theme.textTertiary)
            Text("Latest \(Formatters.metricValue(summary.latest?.value ?? 0)) · Δ \(Formatters.metricDelta(summary.change ?? 0))")
                .typography(.rowTitle).foregroundStyle(Theme.textPrimary)
            Text("Best \(Formatters.metricValue(summary.best ?? 0)) · Avg \(Formatters.metricValue(summary.average)) · n=\(summary.entries.count)")
                .typography(.caption).foregroundStyle(Theme.textSecondary)
        }.padding(Theme.Spacing.lg).surfaceCard().background(Theme.background)
    }
}

#Preview("Metric analytics · fixed sample") {
    MetricAnalyticsPreview().padding().background(Theme.background).preferredColorScheme(.dark)
}
#endif
