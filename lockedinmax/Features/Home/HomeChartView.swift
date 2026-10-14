import Charts
import SwiftUI

struct HomeChartView: View {
    let summary: Analytics.Summary
    let range: TimeRange
    let mode: ChartMode
    @Binding var selectedDate: Date?
    let selectedPoint: Analytics.ChartPoint?

    private var points: [Analytics.ChartPoint] {
        mode == .cumulative ? summary.cumulative : summary.buckets
    }

    private var lineColor: Color {
        guard let delta = summary.deltaHours else { return Theme.accent }
        return delta >= 0 ? Theme.accent : Theme.down
    }

    private var yMaximum: Double {
        let maximum = points.map(\.value).max() ?? 0
        return max(1, maximum * 1.15)
    }

    var body: some View {
        Chart {
            RuleMark(y: .value("Start", points.first?.value ?? 0))
                .foregroundStyle(Theme.hairline)
                .lineStyle(StrokeStyle(lineWidth: Theme.borderWidth, dash: [4, 4]))

            if mode == .cumulative {
                ForEach(points) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Hours", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [lineColor.opacity(0.28), lineColor.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Hours", point.value)
                    )
                    .foregroundStyle(lineColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            } else {
                ForEach(points) { point in
                    BarMark(
                        x: .value("Date", point.date),
                        y: .value("Hours", point.value)
                    )
                    .foregroundStyle(lineColor)
                    .cornerRadius(2)
                }
            }

            if let selectedPoint {
                RuleMark(x: .value("Date", selectedPoint.date))
                    .foregroundStyle(Theme.hairline)
                    .lineStyle(StrokeStyle(lineWidth: Theme.borderWidth, dash: [3, 3]))
                PointMark(
                    x: .value("Date", selectedPoint.date),
                    y: .value("Hours", selectedPoint.value)
                )
                .foregroundStyle(lineColor)
                .symbolSize(64)
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
                        Text(label(for: date))
                            .font(Typography.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .chartYScale(domain: 0...yMaximum)
        .animation(.easeInOut(duration: 0.2), value: range)
        .animation(.easeInOut(duration: 0.2), value: mode)
    }

    private func label(for date: Date) -> String {
        switch range {
        case .day:
            date.formatted(date: .omitted, time: .shortened)
        case .week, .month, .quarter:
            date.formatted(.dateTime.month(.abbreviated).day())
        case .year:
            date.formatted(.dateTime.month(.abbreviated))
        case .all:
            date.formatted(.dateTime.year())
        }
    }
}

#Preview {
    HomeChartView(
        summary: Analytics.summarize(sessions: [], range: .week),
        range: .week,
        mode: .cumulative,
        selectedDate: .constant(nil),
        selectedPoint: nil
    )
    .frame(height: 180)
    .padding(Theme.Spacing.lg)
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
