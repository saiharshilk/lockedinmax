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
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            if metrics.isEmpty {
                emptyState
            } else {
                SectionHeader(title: "METRICS")
                ForEach(orderedMetrics) { metric in
                    NavigationLink { MetricDetailView(metric: metric) } label: { row(metric) }
                        .buttonStyle(.plain)
                }
            }
        }
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
                               text: Formatters.metricDelta(change) + (metric.unit.isEmpty ? "" : " \(metric.unit)"))
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
    }

    private func recentChange(_ sortedEntries: [MetricEntry]) -> Double? {
        guard sortedEntries.count >= 2 else { return nil }
        return sortedEntries[sortedEntries.count - 1].value - sortedEntries[sortedEntries.count - 2].value
    }

    private func latestDate(_ metric: Metric) -> Date {
        entries.filter { $0.metric?.id == metric.id }.map(\.date).max() ?? .distantPast
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text("No scores yet.").typography(.title).foregroundStyle(Theme.textPrimary)
            Text("Log a score with a screenshot to start tracking it.")
                .typography(.body).foregroundStyle(Theme.textSecondary)
            PrimaryButton(title: "LOG A SCORE") {
                appState.logScoreRequested = true
                appState.selectedTab = .log
            }
        }.padding(.vertical, Theme.Spacing.xxl)
    }
}

#Preview {
    NavigationStack { ScoreStatsView() }
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
        .environment(AppState()).preferredColorScheme(.dark)
}
