import SwiftData
import SwiftUI

struct ScoreStatsView: View {
    @Environment(AppState.self) private var appState
    @Query private var metrics: [Metric]
    @Query private var entries: [MetricEntry]

    private var orderedMetrics: [Metric] {
        metrics.sorted { latestDate($0) > latestDate($1) }
    }

    var body: some View {
        Group {
#if DEBUG
            if DebugWorkState.isSeeding {
                ProgressView("Loading sample data...").tint(Theme.accent)
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                scoreContent
            }
#else
            scoreContent
#endif
        }
#if DEBUG
        .onChange(of: appState.sampleDataRefreshVersion) { _, _ in }
#endif
    }

    private var scoreContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            if metrics.isEmpty {
                emptyState
            } else {
                SectionHeader(title: "METRICS")
                    .accessibilityAddTraits(.isHeader)
                ForEach(orderedMetrics, id: \.id) { metric in
                    NavigationLink(value: StatsDestination.metric(metric.id)) { row(metric) }
                        .buttonStyle(.plain)

                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ metric: Metric) -> some View {
        let summary = StatsAnalytics.metricSummary(
            entries: entries.filter { $0.metric?.id == metric.id }, range: .all, now: .now
        )
        let latest = summary.latest?.value
        return HStack(spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(metric.name).typography(.rowTitle).foregroundStyle(Theme.textPrimary)
                if let change = recentChange(summary.entries) {
                    DeltaLabel(value: change,
                               text: Formatters.metricDelta(change) + (metric.unit.isEmpty ? "" : " \(metric.unit)"),
                               neutralText: "0.0\(metric.unit.isEmpty ? "" : " \(metric.unit)")")
                }
            }
            Spacer(minLength: Theme.Spacing.sm)
            Sparkline(values: Array(summary.entries.suffix(14).map(\.value)),
                      color: (summary.change ?? 0) >= 0 ? Theme.up : Theme.down)
            VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                Text(latest.map { Formatters.metric($0, unit: metric.unit) } ?? "—")
                    .typography(.rowTitle).foregroundStyle(Theme.textPrimary)
                Text(summary.latest.map { $0.date.formatted(.dateTime.month(.abbreviated).day()) } ?? "—")
                    .typography(.caption).foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.vertical, Theme.Spacing.md)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 1) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(metric.name), \(summaryText(metric))")
    }

    private func summaryText(_ metric: Metric) -> String {
        let entries = self.entries.filter { $0.metric?.id == metric.id }
        guard let latest = entries.max(by: { $0.date < $1.date }) else { return "No scores yet" }
        let count = entries.count
        return "Latest \(Formatters.metric(latest.value, unit: metric.unit)), \(count) \(count == 1 ? "entry" : "entries")"
    }

    private func recentChange(_ sortedEntries: [MetricEntry]) -> Double? {
        guard sortedEntries.count >= 2 else { return nil }
        return sortedEntries[sortedEntries.count - 1].value - sortedEntries[sortedEntries.count - 2].value
    }

    private func latestDate(_ metric: Metric) -> Date {
        entries.filter { $0.metric?.id == metric.id }.map(\.date).max() ?? .distantPast
    }

    private var emptyState: some View {
        EmptyStateView(title: "No scores yet.",
                       message: "Log a score with a screenshot to start tracking it.",
                       buttonTitle: "LOG A SCORE") {
            appState.logScoreRequested = true
            appState.selectedTab = .log
        }
    }
}

#Preview {
    NavigationStack { ScoreStatsView() }
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
        .environment(AppState()).preferredColorScheme(.dark)
}
