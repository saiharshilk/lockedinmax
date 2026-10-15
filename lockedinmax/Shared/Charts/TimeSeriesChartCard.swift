import Charts
import SwiftUI

enum ChartMode: String, CaseIterable, Hashable {
    case cumulative = "CUMULATIVE"
    case perDay = "PER DAY"
}

struct TimeSeriesChartCard: View {
    let sessions: [Session]
    let label: String
    @Binding var range: TimeRange
    @Binding var mode: ChartMode
    @State private var selectedDate: Date?
    @State private var selectedPoint: Analytics.ChartPoint?
    @State private var scrubTrigger = 0

    private var summary: Analytics.Summary {
        Analytics.summarize(sessions: sessions, range: range)
    }

    private var points: [Analytics.ChartPoint] {
        mode == .cumulative ? summary.cumulative : summary.buckets
    }

    private var lineColor: Color {
        guard let delta = summary.deltaHours else { return Theme.accent }
        return delta >= 0 ? Theme.up : Theme.down
    }

    private var yMaximum: Double { max(1, (points.map(\.value).max() ?? 0) * 1.15) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            hero
            chart.frame(height: 190).clipped()
            RangePillBar(selection: Binding(
                get: { range }, set: { value in
                    withAnimation(.easeInOut(duration: 0.2)) { range = value }
                }
            ))
            modeToggle
        }
        .onChange(of: selectedDate) { _, date in updateSelection(date) }
        .onChange(of: range) { _, _ in clearSelection() }
        .onChange(of: mode) { _, _ in clearSelection() }
        .sensoryFeedback(.selection, trigger: scrubTrigger)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(selectedPoint.map { dateLabel($0.date) } ?? "\(label.uppercased()) · \(range.displayName)")
                .typography(.sectionLabel)
                .foregroundStyle(selectedPoint == nil ? Theme.textTertiary : Theme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                let displayedHours = selectedPoint?.value ?? summary.currentHours
                Text(Formatters.hoursValue(displayedHours))
                    .typography(.heroNumber).foregroundStyle(Theme.textPrimary)
                Text(Formatters.hoursUnit(displayedHours)).typography(.body).foregroundStyle(Theme.textSecondary)
            }
            if selectedPoint == nil, range != .all, let delta = summary.deltaHours {
                DeltaLabel(value: delta,
                           text: "\(Formatters.delta(hours: delta, percent: summary.deltaPercent)) vs previous")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var chart: some View {
        Chart {
            RuleMark(y: .value("Start", points.first?.value ?? 0))
                .foregroundStyle(Theme.hairline)
                .lineStyle(StrokeStyle(lineWidth: Theme.borderWidth, dash: [4, 4]))
            if mode == .cumulative {
                ForEach(points) { point in
                    AreaMark(x: .value("Date", point.date), y: .value("Hours", point.value))
                        .foregroundStyle(LinearGradient(colors: [lineColor.opacity(0.28), .clear],
                                                        startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Date", point.date), y: .value("Hours", point.value))
                        .foregroundStyle(lineColor).lineStyle(StrokeStyle(lineWidth: 2))
                }
            } else {
                ForEach(points) { point in
                    BarMark(x: .value("Date", point.date), y: .value("Hours", point.value))
                        .foregroundStyle(lineColor).cornerRadius(2)
                }
            }
            if let selectedPoint {
                RuleMark(x: .value("Date", selectedPoint.date))
                    .foregroundStyle(Theme.hairline)
                    .lineStyle(StrokeStyle(lineWidth: Theme.borderWidth, dash: [3, 3]))
                PointMark(x: .value("Date", selectedPoint.date), y: .value("Hours", selectedPoint.value))
                    .foregroundStyle(lineColor).symbolSize(64)
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(.clear)
                AxisTick().foregroundStyle(.clear)
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(axisLabel(date)).font(Typography.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .chartYScale(domain: 0...yMaximum)
        .animation(.easeInOut(duration: 0.2), value: range)
        .animation(.easeInOut(duration: 0.2), value: mode)
    }

    private var modeToggle: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Spacer()
            ForEach(ChartMode.allCases, id: \.self) { option in
                Button { withAnimation(.easeInOut(duration: 0.2)) { mode = option } } label: {
                    Text(option.rawValue).foregroundStyle(mode == option ? Theme.accent : Theme.textSecondary)
                }
                .buttonStyle(.plain)
                if option == .cumulative { Text("|").foregroundStyle(Theme.hairline) }
            }
        }
        .typography(.caption).accessibilityLabel("Chart mode")
    }

    private func updateSelection(_ date: Date?) {
        guard let date, let nearest = points.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }) else { selectedPoint = nil; return }
        if nearest.date != selectedPoint?.date || nearest.value != selectedPoint?.value {
            selectedPoint = nearest
            scrubTrigger += 1
        }
    }

    private func clearSelection() { selectedDate = nil; selectedPoint = nil }

    private func dateLabel(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)).uppercased()
    }

    private func axisLabel(_ date: Date) -> String {
        switch range {
        case .day: date.formatted(date: .omitted, time: .shortened)
        case .week, .month, .quarter: date.formatted(.dateTime.month(.abbreviated).day())
        case .year: date.formatted(.dateTime.month(.abbreviated))
        case .all: date.formatted(.dateTime.year())
        }
    }
}

#Preview {
    struct Preview: View {
        @State var range: TimeRange = .week
        @State var mode: ChartMode = .cumulative
        var body: some View {
            TimeSeriesChartCard(sessions: [], label: "Time Invested", range: $range, mode: $mode)
                .padding(Theme.Spacing.lg).background(Theme.background).preferredColorScheme(.dark)
        }
    }
    return Preview()
}
