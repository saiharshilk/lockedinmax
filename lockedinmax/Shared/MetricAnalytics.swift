import Foundation

extension StatsAnalytics {
    struct MetricSummary {
        let entries: [MetricEntry]
        let latest: MetricEntry?
        let change: Double?
        let best: Double?
        let average: Double
    }

    static func metricSummary(entries: [MetricEntry], range: TimeRange, now: Date,
                              calendar: Calendar = .current) -> MetricSummary {
        Analytics.recordRecompute()
#if DEBUG
        if DebugWorkState.isSeeding {
            return MetricSummary(entries: [], latest: nil, change: nil, best: nil, average: 0)
        }
#endif
        let start: Date
        switch range {
        case .day: start = calendar.startOfDay(for: now)
        case .week: start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month: start = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        case .quarter: start = calendar.date(byAdding: .day, value: -90, to: now) ?? now
        case .year: start = calendar.date(byAdding: .day, value: -365, to: now) ?? now
        case .all: start = min(entries.map(\.date).min() ?? now, now)
        }
        let filtered = entries.filter { $0.value.isFinite && $0.date >= start && $0.date <= now }
            .sorted { $0.date < $1.date }
        let change: Double?
        if filtered.count >= 2, let first = filtered.first, let last = filtered.last {
            change = last.value - first.value
        } else {
            change = nil
        }
        let values = filtered.map(\.value)
        return MetricSummary(entries: filtered, latest: filtered.last, change: change, best: values.max(),
                             average: values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count))
    }
}
