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

enum HeatmapLayout {
    static let columnCount = 12
    static let rowCount = 7
    static let labelColumnWidth: CGFloat = 14
    static let gap: CGFloat = 3
    static let fallbackWidth: CGFloat = 300

    static func cellSize(forAvailableWidth width: CGFloat) -> CGFloat {
        let measuredWidth = width.isFinite && width > 0 ? width : fallbackWidth
        // One gap separates the label column from the grid; eleven gaps separate its twelve columns.
        let availableForCells = measuredWidth - labelColumnWidth - 12 * gap
        return min(28, max(10, availableForCells / CGFloat(columnCount)))
    }

#if DEBUG
    static func debugRenderedCellSize(forAvailableWidth width: CGFloat) -> CGFloat {
        cellSize(forAvailableWidth: width)
    }
#endif
}

struct ConsistencyHeatmap: View {
    let sessions: [Session]
    @State private var selectedDate: Date?
    @State private var days: [StatsAnalytics.HeatDay] = []
    @State private var availableWidth = HeatmapLayout.fallbackWidth
    private var selected: StatsAnalytics.HeatDay? { days.first { $0.date == selectedDate } }
    private var calendar: Calendar { .current }
    private var weekdayLabelSymbols: [String] { HeatmapCalendarLayout.weekdayLabels(calendar: calendar) }
    private var cellSize: CGFloat { HeatmapLayout.cellSize(forAvailableWidth: availableWidth) }
    private var gridHeight: CGFloat { cellSize * 7 + HeatmapLayout.gap * 6 }

    init(sessions: [Session]) {
        self.sessions = sessions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "CONSISTENCY").accessibilityAddTraits(.isHeader)
            GeometryReader { geometry in
                let width = geometry.size.width.isFinite && geometry.size.width > 0
                    ? geometry.size.width : HeatmapLayout.fallbackWidth
                let size = HeatmapLayout.cellSize(forAvailableWidth: width)
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack(alignment: .top, spacing: HeatmapLayout.gap) {
                        weekdayLabelView(cellSize: size)
                            .frame(width: HeatmapLayout.labelColumnWidth, height: gridHeight, alignment: .top)
                        HStack(alignment: .top, spacing: HeatmapLayout.gap) {
                            ForEach(0..<HeatmapLayout.columnCount, id: \.self) { column in
                                VStack(spacing: HeatmapLayout.gap) {
                                    ForEach(0..<HeatmapLayout.rowCount, id: \.self) { row in
                                        cell(column: column, row: row, size: size)
                                    }
                                }
                                .frame(width: size)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onAppear { availableWidth = width }
                    .onChange(of: geometry.size.width) { _, newWidth in
                        availableWidth = newWidth.isFinite && newWidth > 0
                            ? newWidth : HeatmapLayout.fallbackWidth
                    }
                    legend(size: size)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: gridHeight + 34)
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

    @ViewBuilder private func cell(column: Int, row: Int, size: CGFloat) -> some View {
        if let day = dayAt(column: column, row: row) {
            if day.isFuture {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.background.opacity(0.35))
                    .frame(width: size, height: size)
                    .accessibilityHidden(true)
            } else {
                Button { selectedDate = day.date } label: {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(day.level == 0 ? Theme.surface : Theme.accent.opacity(Double(day.level) / 4))
                        .overlay {
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(day.isToday ? Theme.accent : Theme.hairline,
                                        lineWidth: day.isToday || day.level == 0 ? 1 : 0)
                        }
                        .frame(width: size, height: size)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(StatsFormat.day(day.date)), \(Formatters.hours(day.hours))")
                .accessibilityValue("\(calendar.weekdaySymbols[calendar.component(.weekday, from: day.date) - 1]); select day")
            }
        } else {
            Color.clear.frame(width: size, height: size).accessibilityHidden(true)
        }
    }

    private func updateDays() {
        days = StatsAnalytics.heatmap(sessions: sessions, today: .now)
        if let selectedDate, !days.contains(where: { $0.date == selectedDate }) {
            self.selectedDate = nil
        }
    }

    private func weekdayLabelView(cellSize: CGFloat) -> some View {
        VStack(spacing: HeatmapLayout.gap) {
            ForEach(Array(weekdayLabelSymbols.enumerated()), id: \.offset) { _, label in
                Text(label).typography(.caption).foregroundStyle(Theme.textSecondary)
                    .frame(width: HeatmapLayout.labelColumnWidth, height: cellSize)
            }
        }.frame(maxHeight: .infinity, alignment: .top)
    }

    private func legend(size: CGFloat) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text("less").typography(.caption).foregroundStyle(Theme.textSecondary)
            ForEach(1...4, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.accent.opacity(Double(level) / 4))
                    .frame(width: min(10, size * 0.45), height: min(10, size * 0.45))
            }
            Text("more").typography(.caption).foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Less to more time invested")
    }

    private func dayAt(column: Int, row: Int) -> StatsAnalytics.HeatDay? {
        let index = column * HeatmapLayout.rowCount + row
        return days.indices.contains(index) ? days[index] : nil
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
        TimeStatsInsights(summary: StatsAnalytics.summarize(sessions: [], kind: .week, anchor: .now, now: .now))
        ConsistencyHeatmap(sessions: [])
    }.padding().background(Theme.background)
}
