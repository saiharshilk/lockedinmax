import SwiftData
import SwiftUI

struct StatsView: View {
    @State private var segment: StatsSegment = .time

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                StatsSegments(selection: $segment)
                if segment == .time {
                    TimeStatsView()
                } else {
                    ScoreStatsView()
                }
            }
            .padding(Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.accent)
    }
}

enum StatsSegment: String, CaseIterable { case time = "TIME", scores = "SCORES" }

#Preview {
    NavigationStack { StatsView() }
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
        .environment(AppState()).preferredColorScheme(.dark)
}
