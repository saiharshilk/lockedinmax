import SwiftUI

struct ActivityStatsGrid: View {
    let sessions: [Session]

    private var byDay: [Date: Double] {
        Dictionary(grouping: sessions) { Calendar.current.startOfDay(for: $0.date) }
            .mapValues { $0.reduce(0) { $0 + $1.hours } }
    }

    private var total: Double { sessions.reduce(0) { $0 + $1.hours } }
    private var activeAverage: Double { byDay.isEmpty ? 0 : total / Double(byDay.count) }
    private var bestDay: (date: Date, hours: Double)? {
        byDay.max { $0.value < $1.value }.map { ($0.key, $0.value) }
    }
    private var streak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let firstDay: Date
        if byDay[today] != nil { firstDay = today }
        else { firstDay = calendar.date(byAdding: .day, value: -1, to: today) ?? today }
        guard byDay[firstDay] != nil else { return 0 }
        var count = 0
        var day = firstDay
        while byDay[day] != nil {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "STATS")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.md) {
                stat(title: "TOTAL", value: Formatters.hours(total))
                stat(title: "AVG / ACTIVE DAY", value: Formatters.hours(activeAverage))
                stat(title: "BEST DAY", value: bestDay.map { Formatters.hours($0.hours) } ?? Formatters.hours(0),
                     detail: bestDay.map { $0.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)).uppercased() })
                stat(title: "STREAK", value: "\(streak) \(streak == 1 ? "day" : "days")")
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

#Preview {
    ActivityStatsGrid(sessions: []).padding(Theme.Spacing.lg).background(Theme.background)
}
