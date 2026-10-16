import Charts
import SwiftData
import SwiftUI

private extension Collection {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}

struct TimeStatsView: View {
    @Environment(AppState.self) private var appState
    @Query private var sessions: [Session]
    @Query private var activities: [Activity]
    @State private var kind: StatsPeriodKind = .week
    @State private var anchor = Date.now
    @State private var selectedBucket: Int?
    @State private var selectionTick = 0

    private var summary: StatsAnalytics.Summary {
        StatsAnalytics.summarize(sessions: sessions, kind: kind, anchor: anchor, now: .now)
    }
    private var isCurrentPeriod: Bool {
        let current = StatsAnalytics.period(kind: kind, anchor: .now)
        return anchor >= current.start && anchor < current.end
    }
    private let chartHeight: CGFloat = 190
    private var periodSegment: Binding<StatsPeriodKind> {
        Binding(get: { kind }, set: { kind = $0; anchor = .now; selectedBucket = nil; selectionTick += 1 })
    }

    var body: some View {
        Group {
#if DEBUG
            if DebugWorkState.isSeeding {
                ProgressView("Loading sample data...").tint(Theme.accent)
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                statsContent
            }
#else
            statsContent
#endif
        }
        .sensoryFeedback(.selection, trigger: selectionTick)
#if DEBUG
        .onChange(of: appState.sampleDataRefreshVersion) { _, _ in }
#endif
    }

    private var statsContent: some View {
        Group {
            if sessions.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    StatsSegments(selection: periodSegment)
                    navigator
                    summaryHeader
                    if summary.totalHours == 0 { Text("No sessions this period").typography(.caption).foregroundStyle(Theme.textSecondary) }
                    stackedChart
                    TimeStatsBreakdown(summary: summary, activities: activities)
                    TimeStatsInsights(summary: summary)
                    ConsistencyHeatmap(sessions: sessions)
                }
                .animation(.easeInOut(duration: 0.2), value: kind)
                .animation(.easeInOut(duration: 0.2), value: anchor)
            }
        }
    }

    private var navigator: some View {
        HStack {
            Button { move(-1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(periodLabel).typography(.sectionLabel).foregroundStyle(Theme.textPrimary)
            Spacer()
            Button { move(1) } label: { Image(systemName: "chevron.right") }
                .disabled(isCurrentPeriod).opacity(isCurrentPeriod ? 0.3 : 1)
        }
        .font(.system(size: 14, weight: .semibold, design: .monospaced))
        .foregroundStyle(Theme.accent)
    }

    private var periodLabel: String {
        StatsFormat.period(kind, period: summary.period)
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("TIME INVESTED").typography(.sectionLabel).foregroundStyle(Theme.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                Text(Formatters.hoursValue(summary.totalHours)).typography(.heroNumber).foregroundStyle(Theme.textPrimary)
                Text(Formatters.hoursUnit(summary.totalHours)).typography(.body).foregroundStyle(Theme.textSecondary)
            }
            if summary.deltaPercent != nil || summary.deltaHours != 0 {
                DeltaLabel(value: summary.deltaHours,
                           text: "\(Formatters.delta(hours: summary.deltaHours, percent: summary.deltaPercent)) vs previous")
            }
        }
    }

    private var stackedChart: some View {
        Chart {
                ForEach(summary.bucketValues) { item in
                    if activities.first(where: { $0.id == item.activityID }) != nil {
                        BarMark(x: .value("Bucket", item.bucket), y: .value("Hours", item.hours))
                            .foregroundStyle(by: .value("Activity", item.activityID.uuidString))
                            .opacity(selectedBucket == nil || selectedBucket == item.bucket ? 1 : 0.4)
                    }
                }
                if let selectedBucket {
                    RuleMark(x: .value("Selected", selectedBucket))
                        .foregroundStyle(Theme.textTertiary.opacity(0.5))
                }
            }
            .chartForegroundStyleScale(domain: activities.map { $0.id.uuidString },
                                       range: activities.map { Theme.activityColor($0.colorHex) })
            .chartYScale(domain: 0...max(1, (summary.bucketValues.reduce(into: [Int: Double]()) { totals, item in
            totals[item.bucket, default: 0] += item.hours
        }.values.max() ?? 0) * 1.15))
            .chartLegend(.hidden).chartYAxis(.hidden)
            .chartXAxis { axis }
            .chartXScale(domain: -0.5...Double(summary.period.bucketDates.count) - 0.5)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    if let selectedBucket, let plot = proxy.plotFrame.map({ geometry[$0] }) {
                        let cardWidth = min(210, max(100, geometry.size.width - Theme.Spacing.lg))
                        tooltip(selectedBucket)
                            .frame(width: cardWidth)
                            .position(x: min(max(plot.minX + (CGFloat(selectedBucket) + 0.5) * plot.width / CGFloat(max(summary.period.bucketDates.count, 1)), cardWidth / 2 + Theme.Spacing.xs), geometry.size.width - cardWidth / 2 - Theme.Spacing.xs),
                                      y: min(max(plot.minY + 58, 54), max(54, plot.maxY - 54)))
                            .allowsHitTesting(false)
                    }
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                            guard let plot = proxy.plotFrame.map({ geometry[$0] }) else { return }
                            let x = value.location.x - plot.minX
                            if let bucket: Int = proxy.value(atX: x), summary.period.bucketDates.indices.contains(bucket), bucket != selectedBucket {
                                selectedBucket = bucket
                                selectionTick += 1
                            }
                        }.onEnded { _ in selectedBucket = nil })
                }
            }
            .frame(height: chartHeight)
            .clipped()
    }

    @AxisContentBuilder private var axis: some AxisContent {
        AxisMarks(values: axisValues) { value in
            AxisGridLine().foregroundStyle(.clear)
            AxisTick().foregroundStyle(.clear)
            if let index = value.as(Int.self), let date = summary.period.bucketDates[safe: index] {
                AxisValueLabel { Text(axisLabel(date, index: index)).typography(.caption).foregroundStyle(Theme.textSecondary) }
            }
        }
    }

    private var axisValues: [Int] {
        switch kind {
        case .day: [0, 6, 12, 18]
        case .week: Array(0..<7)
        case .month: stride(from: 5, through: summary.period.bucketDates.count, by: 5).map { $0 - 1 }
        }
    }

    private func axisLabel(_ date: Date, index: Int) -> String {
        switch kind {
        case .day:
            switch index {
            case 0: return "12AM"
            case 6: return "6AM"
            case 12: return "12PM"
            default: return "6PM"
            }
        case .week:
            let weekday = Calendar.current.component(.weekday, from: date)
            let symbolIndex = (weekday - Calendar.current.firstWeekday + 7) % 7
            return Calendar.current.veryShortStandaloneWeekdaySymbols[symbolIndex]
        case .month: return "\(Calendar.current.component(.day, from: date))"
        }
    }

    private func tooltip(_ bucket: Int) -> some View {
        let values = summary.bucketValues.filter { $0.bucket == bucket && $0.hours > 0 }
        let total = values.reduce(0) { $0 + $1.hours }
        let visibleValues = Array(values.prefix(3))
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(summary.period.bucketDates[safe: bucket].map { StatsFormat.day($0) } ?? "")
                .typography(.sectionLabel).foregroundStyle(Theme.textTertiary)
            Text(Formatters.hours(total)).typography(.rowTitle).foregroundStyle(Theme.textPrimary)
            ForEach(visibleValues) { value in
                HStack { Text(value.activityName).lineLimit(1); Spacer(); Text(Formatters.hours(value.hours)) }
                    .typography(.caption).foregroundStyle(Theme.textSecondary)
            }
            if values.count > visibleValues.count {
                Text("+ \(values.count - visibleValues.count) MORE POSITIONS")
                    .typography(.caption).foregroundStyle(Theme.textSecondary)
            }
        }.padding(Theme.Spacing.md).surfaceCard().frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text("Nothing on the board.").typography(.title).foregroundStyle(Theme.textPrimary)
            Text("Log your time to see your portfolio take shape.").typography(.body).foregroundStyle(Theme.textSecondary)
            PrimaryButton(title: "LOG A SESSION") { appState.selectedTab = .log }
        }.padding(.vertical, Theme.Spacing.xxl)
    }

    private func move(_ offset: Int) {
        let component: Calendar.Component = kind == .day ? .day : kind == .week ? .weekOfYear : .month
        if let next = Calendar.current.date(byAdding: component, value: offset, to: anchor) {
            anchor = next
            selectedBucket = nil
            selectionTick += 1
        }
    }
}

#Preview {
    NavigationStack { TimeStatsView() }
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
        .environment(AppState()).preferredColorScheme(.dark)
}
