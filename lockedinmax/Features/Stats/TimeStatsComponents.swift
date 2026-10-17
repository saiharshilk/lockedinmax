import SwiftData
import SwiftUI

struct TimeStatsBreakdown: View {
    let summary: StatsAnalytics.Summary
    let activities: [Activity]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "BREAKDOWN")
            if summary.breakdown.isEmpty { Text("No activity totals.").typography(.caption).foregroundStyle(Theme.textSecondary) }
            ForEach(summary.breakdown) { item in
                if let activity = activities.first(where: { $0.id == item.id }) {
                    NavigationLink { ActivityDetailView(activityID: activity.id) } label: { row(item) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func row(_ item: StatsAnalytics.ActivitySlice) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: item.iconName).foregroundStyle(Theme.onAccent)
                    .frame(width: 30, height: 30).background(Theme.activityColor(item.colorHex), in: Circle())
                Text(item.name).typography(.rowTitle).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(Formatters.hours(item.hours)).typography(.rowTitle).foregroundStyle(Theme.textPrimary)
                Text(Formatters.percent(item.share * 100)).typography(.caption).foregroundStyle(Theme.textSecondary)
            }
            GeometryReader { geometry in
                Capsule().fill(Theme.hairline).overlay(alignment: .leading) {
                    Capsule().fill(Theme.activityColor(item.colorHex)).frame(width: geometry.size.width * item.share)
                }
            }.frame(height: 3)
        }.padding(.vertical, Theme.Spacing.xs)
    }
}

struct TimeStatsInsights: View {
    let summary: StatsAnalytics.Summary
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "INSIGHTS")
            LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
                stat("ACTIVE DAYS", "\(summary.activeDays) / \(summary.daysSoFar)")
                stat("AVG / ACTIVE DAY", Formatters.hours(summary.averagePerActiveDay))
                stat("BEST DAY", summary.bestDay.map { Formatters.hours($0.hours) } ?? "0.0 hrs",
                     detail: summary.bestDay.map { StatsFormat.day($0.date) } ?? "—")
                stat("TOP POSITION", summary.topPosition?.name ?? "—",
                     detail: summary.topPosition.map { Formatters.hours($0.hours) })
            }
        }
    }

    private func stat(_ title: String, _ value: String, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title).typography(.sectionLabel).foregroundStyle(Theme.textTertiary)
            Text(value).typography(.rowTitle).foregroundStyle(Theme.textPrimary).lineLimit(1).minimumScaleFactor(0.7)
            if let detail { Text(detail).typography(.caption).foregroundStyle(Theme.textSecondary) }
        }.frame(maxWidth: .infinity, minHeight: 68, alignment: .leading).padding(Theme.Spacing.md).surfaceCard()
    }
}

struct ConsistencyHeatmap: View {
    let sessions: [Session]
    @State private var selectedDate: Date?
    private var selected: StatsAnalytics.HeatDay? { days.first { $0.date == selectedDate } }
    @State private var days: [StatsAnalytics.HeatDay] = []
    private let labels = ["M", "", "W", "", "F", "", ""]

    init(sessions: [Session]) {
        self.sessions = sessions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "CONSISTENCY")
            HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                weekdayLabels
                LazyHGrid(rows: heatmapRows, spacing: 3) {
                    ForEach(days) { day in
                        Button { selectedDate = day.date } label: {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(day.level == 0 ? Theme.surface : Theme.accent.opacity(Double(day.level) * 0.22))
                                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.hairline, lineWidth: day.level == 0 ? 1 : 0))
                                .frame(width: 11, height: 11)
                        }.buttonStyle(.plain).accessibilityLabel("\(StatsFormat.day(day.date)), \(Formatters.hours(day.hours))")
                    }
                }
            }
            if let selected {
                Text("\(StatsFormat.day(selected.date)) · \(Formatters.hours(selected.hours))")
                    .typography(.caption).foregroundStyle(Theme.textSecondary)
            }
        }
        .task(id: "\(sessions.count)-\(DebugWorkState.generation)") {
            guard !DebugWorkState.isSeeding else { return }
            days = StatsAnalytics.heatmap(sessions: sessions, today: .now)
            if let selectedDate, !days.contains(where: { $0.date == selectedDate }) {
                self.selectedDate = nil
            }
        }
    }

    private var weekdayLabels: some View {
        VStack(spacing: 3) {
            ForEach(Array(labels.enumerated()), id: \.offset) { _, label in
                Text(label).typography(.caption).foregroundStyle(Theme.textSecondary).frame(width: 12, height: 11)
            }
        }
    }

    private var heatmapRows: [GridItem] {
        Array(repeating: GridItem(.fixed(11), spacing: 3), count: 7)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
        TimeStatsInsights(summary: StatsAnalytics.summarize(sessions: [], kind: .week, anchor: .now, now: .now))
        ConsistencyHeatmap(sessions: [])
    }.padding().background(Theme.background)
}
