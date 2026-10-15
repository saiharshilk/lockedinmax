import SwiftUI

#if DEBUG
private struct StatsAnalyticsPreview: View {
    private let summary: StatsAnalytics.Summary
    private let sessions: [Session]

    init() {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 12)) ?? .now
        let period = StatsAnalytics.period(kind: .week, anchor: now, calendar: calendar)
        let math = Activity(name: "Math", colorHex: Theme.activityColorPresets[0], iconName: "function")
        let chess = Activity(name: "Chess", colorHex: Theme.activityColorPresets[2], iconName: "crown")
        sessions = [
            Session(date: period.start.addingTimeInterval(3_600), hours: 1.5, activity: math),
            Session(date: period.start.addingTimeInterval(14_400), hours: 1.0, activity: chess),
            Session(date: period.start.addingTimeInterval(2 * 86_400 + 9_000), hours: 2.0, activity: math),
            Session(date: period.previousStart.addingTimeInterval(10_000), hours: 1.0, activity: chess)
        ]
        let computed = StatsAnalytics.summarize(sessions: sessions, kind: .week, anchor: now, now: now, calendar: calendar)
        assert(computed.period.bucketDates.count == 7)
        assert(computed.totalHours == 4.5)
        assert(computed.previousHours == 1.0)
        assert(computed.breakdown.map(\.share).reduce(0, +) == 1.0)
        assert(StatsAnalytics.heatmap(sessions: sessions, today: now, calendar: calendar).count == 84)
        summary = computed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            Text("\(Formatters.hours(summary.totalHours)) · Δ \(Formatters.delta(hours: summary.deltaHours, percent: summary.deltaPercent))")
                .typography(.rowTitle).foregroundStyle(Theme.textPrimary)
            TimeStatsBreakdown(summary: summary, activities: sessions.compactMap(\.activity).reduce(into: [Activity]()) { list, activity in
                if !list.contains(where: { $0.id == activity.id }) { list.append(activity) }
            })
            TimeStatsInsights(summary: summary)
            ConsistencyHeatmap(sessions: sessions)
        }.padding(Theme.Spacing.lg).background(Theme.background)
    }
}

#Preview("Stats analytics · fixed sample") {
    StatsAnalyticsPreview().preferredColorScheme(.dark)
}
#endif
