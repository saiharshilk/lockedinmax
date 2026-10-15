import Charts
import SwiftUI

struct MetricChartCard: View {
    let metric: Metric
    let entries: [MetricEntry]
    @Binding var range: TimeRange
    @State private var selectedDate: Date?
    @State private var selected: MetricEntry?
    @State private var selectionTick = 0

    private var summary: StatsAnalytics.MetricSummary {
        StatsAnalytics.metricSummary(entries: entries, range: range, now: .now)
    }
    private var points: [MetricEntry] { summary.entries }
    private var displayed: MetricEntry? { selected ?? summary.latest }
    private var change: Double? { summary.change }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(selected == nil ? "LATEST" : "SELECTED")
                    .typography(.sectionLabel).foregroundStyle(Theme.textTertiary)
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                    Text(Formatters.metricValue(displayed?.value ?? 0)).typography(.heroNumber).foregroundStyle(Theme.textPrimary)
                    if !metric.unit.isEmpty { Text(metric.unit).typography(.body).foregroundStyle(Theme.textSecondary) }
                }
                if let displayed {
                    Text(displayed.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year()))
                        .typography(.caption).foregroundStyle(Theme.textSecondary)
                }
                if selected == nil, let change {
                    DeltaLabel(value: change, text: "\(Formatters.metricDelta(change)) vs first entry")
                }
            }
            chart.frame(height: 210).clipped()
            RangePillBar(selection: $range)
        }
        .padding(Theme.Spacing.lg).surfaceCard()
        .onChange(of: selectedDate) { _, date in selectNearest(to: date) }
        .onChange(of: range) { _, _ in selectedDate = nil; selected = nil }
        .sensoryFeedback(.selection, trigger: selectionTick)
    }

    private var chart: some View {
        Chart {
            if points.count == 1, let point = points.first {
                PointMark(x: .value("Date", point.date), y: .value("Score", point.value))
                    .foregroundStyle(lineColor).symbolSize(55)
            } else {
                ForEach(points) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Score", point.value))
                        .foregroundStyle(lineColor).lineStyle(StrokeStyle(lineWidth: 2))
                    PointMark(x: .value("Date", point.date), y: .value("Score", point.value))
                        .foregroundStyle(lineColor).symbolSize(selected?.id == point.id ? 65 : 28)
                }
            }
            if let selected {
                RuleMark(x: .value("Selected", selected.date)).foregroundStyle(Theme.hairline)
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: axisDates) { value in
                AxisGridLine().foregroundStyle(.clear)
                AxisTick().foregroundStyle(.clear)
                if let date = value.as(Date.self) {
                    AxisValueLabel { Text(axisLabel(date)).typography(.caption).foregroundStyle(Theme.textSecondary) }
                }
            }
        }
        .chartYScale(domain: yDomain)
        .chartLegend(.hidden)
        .simultaneousGesture(DragGesture(minimumDistance: 0).onEnded { _ in
            selectedDate = nil
            selected = nil
        })
    }

    private var lineColor: Color { (change ?? 0) >= 0 ? Theme.up : Theme.down }
    private var yDomain: ClosedRange<Double> {
        guard let minValue = points.map(\.value).min(), let maxValue = points.map(\.value).max() else { return 0...1 }
        let spread = maxValue - minValue
        let padding = spread == 0 ? max(abs(maxValue), 1) * 0.1 : max(spread * 0.1, max(abs(minValue), 1) * 0.05)
        return (minValue - padding)...(maxValue + padding)
    }

    private var usesTimeAxis: Bool {
        guard let first = points.map(\.date).min(), let last = points.map(\.date).max() else { return false }
        let firstDay = Calendar.current.startOfDay(for: first)
        let lastDay = Calendar.current.startOfDay(for: last)
        return (Calendar.current.dateComponents([.day], from: firstDay, to: lastDay).day ?? 0) <= 2
    }

    private var axisDates: [Date] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = usesTimeAxis ? "h a" : "MMM d"
        let unique = points.sorted { $0.date < $1.date }.reduce(into: [Date]()) { result, entry in
            let label = formatter.string(from: entry.date)
            if !result.contains(where: { formatter.string(from: $0) == label }) { result.append(entry.date) }
        }
        guard unique.count > 3 else { return unique }
        return [unique[0], unique[unique.count / 2], unique[unique.count - 1]]
    }

    private func axisLabel(_ date: Date) -> String {
        usesTimeAxis
            ? date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated))).uppercased()
            : date.formatted(.dateTime.month(.abbreviated).day()).uppercased()
    }

    private func selectNearest(to date: Date?) {
        guard let date, let nearest = points.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }) else { selected = nil; return }
        if selected?.id != nearest.id { selected = nearest; selectionTick += 1 }
    }
}

#Preview {
    struct Preview: View {
        @State var range: TimeRange = .month
        let metric = Metric(name: "Sleep Score", unit: "pts")
        var body: some View {
            MetricChartCard(metric: metric, entries: [
                MetricEntry(date: .now.addingTimeInterval(-86_400 * 14), value: 71),
                MetricEntry(date: .now.addingTimeInterval(-86_400 * 7), value: 78),
                MetricEntry(date: .now, value: 84)
            ], range: $range).padding().background(Theme.background)
        }
    }
    return Preview().preferredColorScheme(.dark)
}
