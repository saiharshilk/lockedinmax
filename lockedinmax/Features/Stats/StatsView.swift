import SwiftData
import SwiftUI

struct StatsView: View {
    @State private var segment: StatsSegment = .time

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                Text("Stats").typography(.title).foregroundStyle(Theme.textPrimary)
                    .padding(.top, Theme.Spacing.md)
                    .accessibilityAddTraits(.isHeader)
                StatsSegments(selection: $segment)
                if segment == .time {
                    TimeStatsView()
                } else {
                    ScoreStatsView()
                        .navigationDestination(for: UUID.self) { metricID in
                            MetricDetailView(metricID: metricID)
                        }
                }
            }
            .padding(Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .tabBarClearance()
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: StatsDestination.self) { destination in
            switch destination {
            case .activity(let id): ActivityDetailView(activityID: id)
            case .metric(let id): MetricDetailView(metricID: id)
            }
        }
        .tint(Theme.accent)
    }
}

enum StatsDestination: Hashable {
    case activity(UUID)
    case metric(UUID)
}

enum StatsSegment: String, CaseIterable { case time = "TIME", scores = "SCORES" }

#Preview {
    NavigationStack { StatsView() }
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
        .environment(AppState()).preferredColorScheme(.dark)
}
