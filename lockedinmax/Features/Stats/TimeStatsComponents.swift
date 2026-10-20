import SwiftData
import SwiftUI

enum HeatmapCalendarLayout {
    static func weekdayLabels(calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        return (0..<7).map { row in
            let weekday = ((calendar.firstWeekday - 1 + row) % 7) + 1
            guard weekday == 2 || weekday == 4 || weekday == 6 else { return "" }
            return symbols[weekday - 1]
        }
    }

    static func gridPosition(for date: Date, firstDate: Date, calendar: Calendar) -> (column: Int, row: Int)? {
        guard let dayOffset = calendar.dateComponents([.day], from: firstDate,
                                                      to: calendar.startOfDay(for: date)).day,
              dayOffset >= 0 else { return nil }
        return (column: dayOffset / 7, row: dayOffset % 7)
    }
}

struct TimeStatsBreakdown: View {
    let summary: StatsAnalytics.Summary
    let activities: [Activity]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "BREAKDOWN").accessibilityAddTraits(.isHeader)
            if summary.breakdown.isEmpty { Text("No activity totals.").typography(.caption).foregroundStyle(Theme.textSecondary) }
            ForEach(summary.breakdown) { item in
                if activities.contains(where: { $0.id == item.id }) {
                    NavigationLink(value: StatsDestination.activity(item.id)) { row(item) }
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
                    .frame(width: Theme.minimumTapHeight, height: Theme.minimumTapHeight)
                    .contentShape(Circle())
                Text(item.name).typography(.rowTitle).foregroundStyle(Theme.textPrimary)
                    .lineLimit(1).truncationMode(.tail).layoutPriority(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: Theme.Spacing.xs)
                VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                    Text(Formatters.hours(item.hours)).typography(.caption)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text(Formatters.percent(item.share * 100)).typography(.caption).foregroundStyle(Theme.textSecondary)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(width: 96, alignment: .trailing)
                .layoutPriority(1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(item.name), \(Formatters.hours(item.hours)), \(Formatters.percent(item.share * 100)) of this period")
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
            SectionHeader(title: "INSIGHTS").accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
                stat("ACTIVE DAYS", "\(summary.activeDays) / \(summary.elapsedDays)")
                stat("AVG / ACTIVE DAY", Formatters.hours(summary.averagePerActiveDay))
                stat("BEST DAY", summary.bestDay.map { Formatters.hours($0.hours) } ?? Formatters.hours(0),
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
    @State private var availableWidth: CGFloat = 0
    private var calendar: Calendar { .current }
    private var weekdayLabelSymbols: [String] { HeatmapCalendarLayout.weekdayLabels(calendar: calendar) }
    private var cellSize: CGFloat {
        let labelColumn: CGFloat = 20
        let gaps = Theme.Spacing.xs + 11 * 3
        let measured = (availableWidth - labelColumn - gaps) / 12
        return availableWidth > 0 ? min(28, max(10, measured)) : 11
    }

    init(sessions: [Session]) {
        self.sessions = sessions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "CONSISTENCY").accessibilityAddTraits(.isHeader)
            GeometryReader { geometry in
                HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                    weekdayLabelView
                        .frame(width: 20, height: cellSize * 7 + 18, alignment: .top)
                    ForEach(0..<12, id: \.self) { column in
                        VStack(spacing: 3) {
                            ForEach(0..<7, id: \.self) { row in
                                if let day = dayAt(column: column, row: row) {
                                    Button { selectedDate = day.date } label: {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(day.level == 0 ? Theme.surface : Theme.accent.opacity(Double(day.level) * 0.22))
                                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.hairline, lineWidth: day.level == 0 ? 1 : 0))
                                            .frame(width: cellSize, height: cellSize)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(StatsFormat.day(day.date)), \(Formatters.hours(day.hours))")
                                    .accessibilityValue("\(calendar.weekdaySymbols[calendar.component(.weekday, from: day.date) - 1]); select day")
                                } else {
                                    Color.clear.frame(width: cellSize, height: cellSize).accessibilityHidden(true)
                                }
                            }
                        }
                        .frame(width: cellSize)
                    }
                    .frame(width: min(geometry.size.width - 20 - Theme.Spacing.xs, 12 * cellSize + 11 * 3), alignment: .leading)
                    .clipped()
                }
                .onAppear { availableWidth = geometry.size.width }
                .onChange(of: geometry.size.width) { _, width in availableWidth = width }
            }
            .frame(maxWidth: .infinity)        .frame(height: cellSize * 7 + 18)
        .clipped()
            if let selected {
                Text("\(StatsFormat.day(selected.date)) · \(Formatters.hours(selected.hours))")
                    .typography(.caption).foregroundStyle(Theme.textSecondary)
            }
        }
#if DEBUG
        .task(id: "\(sessions.count)-\(DebugWorkState.generation)") {
            guard !DebugWorkState.isSeeding else { return }
            updateDays()
        }
#else
        .task(id: sessions.count) { updateDays() }
#endif
    }

    private func updateDays() {
        days = StatsAnalytics.heatmap(sessions: sessions, today: .now)
        if let selectedDate, !days.contains(where: { $0.date == selectedDate }) {
            self.selectedDate = nil
        }
    }

    private var weekdayLabelView: some View {
        VStack(spacing: 3) {
            ForEach(Array(weekdayLabelSymbols.enumerated()), id: \.offset) { _, label in
                Text(label).typography(.caption).foregroundStyle(Theme.textSecondary)
                    .frame(width: 18, height: cellSize)
            }
        }.frame(maxHeight: .infinity, alignment: .top)
    }

    private func dayAt(column: Int, row: Int) -> StatsAnalytics.HeatDay? {
        let index = column * 7 + row
        return days.indices.contains(index) ? days[index] : nil
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
        TimeStatsInsights(summary: StatsAnalytics.summarize(sessions: [], kind: .week, anchor: .now, now: .now))
        ConsistencyHeatmap(sessions: [])
    }.padding().background(Theme.background)
}
