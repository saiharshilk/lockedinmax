import SwiftUI

struct ActivityStatsGrid: View {
    let sessions: [Session]

    private var statistics: ActivityStats.Summary {
        ActivityStats.calculate(sessions: sessions, now: .now)
    }

    private var bestDayDetail: String {
        statistics.bestDay.map { ActivityStats.dayLabel($0.date) } ?? "—"
    }

    private var streakText: String {
        let days = statistics.streakDays
        return "\(days) \(days == 1 ? "day" : "days")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "STATS")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.md) {
                stat(title: "TOTAL", value: Formatters.hours(statistics.totalHours))
                stat(title: "AVG / ACTIVE DAY", value: Formatters.hours(statistics.averageHoursPerActiveDay))
                stat(title: "BEST DAY", value: Formatters.hours(statistics.bestDay?.hours ?? 0),
                     detail: bestDayDetail)
                stat(title: "STREAK", value: streakText)
            }
        }
    }

    private func stat(title: String, value: String, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title).typography(.sectionLabel).foregroundStyle(Theme.textTertiary)
            Text(value).typography(.rowTitle).foregroundStyle(Theme.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
            if let detail {
                Text(detail).typography(.caption).foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .padding(Theme.Spacing.md)
        .surfaceCard()
    }
}

#Preview("Activity stats · sample week") {
    ActivityStatsSamplePreview()
}

private struct ActivityStatsSamplePreview: View {
    private let sessions: [Session]

    init() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let fourDaysAgo = calendar.date(byAdding: .day, value: -4, to: today) ?? today
        sessions = [
            Session(date: calendar.date(byAdding: .hour, value: 9, to: today) ?? today, hours: 1.0),
            Session(date: calendar.date(byAdding: .hour, value: 14, to: today) ?? today, hours: 2.0),
            Session(date: calendar.date(byAdding: .hour, value: 12, to: yesterday) ?? yesterday, hours: 1.5),
            Session(date: calendar.date(byAdding: .hour, value: 12, to: fourDaysAgo) ?? fourDaysAgo, hours: 3.0)
        ]
        let stats = ActivityStats.calculate(sessions: sessions, now: .now, calendar: calendar)
        assert(stats.totalHours == 7.5)
        assert(stats.averageHoursPerActiveDay == 2.5)
        assert(stats.bestDay?.hours == 3.0)
        assert(stats.streakDays == 2)
    }

    var body: some View {
        ActivityStatsGrid(sessions: sessions)
            .padding(Theme.Spacing.lg).background(Theme.background)
    }
}
