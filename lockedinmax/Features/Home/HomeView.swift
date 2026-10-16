import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Query private var sessions: [Session]
    @Query private var activities: [Activity]
    @State private var range: TimeRange = .week
    @State private var mode: ChartMode = .cumulative
#if DEBUG
    @State private var showingDesign = false
#endif

    private var summary: Analytics.Summary {
        Analytics.summarize(sessions: sessions, range: range)
    }

    var body: some View {
        Group {
#if DEBUG
            if DebugWorkState.isSeeding {
                ProgressView("Loading sample data...").tint(Theme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                homeContent
            }
#else
            homeContent
#endif
        }
        .background(Theme.background.ignoresSafeArea())
#if DEBUG
        .onChange(of: appState.sampleDataRefreshVersion) { _, _ in }
#endif
        .navigationTitle("")
        .toolbar {
#if DEBUG
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("DESIGN") { showingDesign = true }
                    .typography(.sectionLabel)
                    .foregroundStyle(Theme.accent)
            }
#endif
        }
#if DEBUG
        .sheet(isPresented: $showingDesign) {
            NavigationStack {
                DesignSystemPreview()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showingDesign = false }
                        }
                    }
            }
            .tint(Theme.accent)
        }
#endif
    }

    private var homeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                header

                if sessions.isEmpty {
                    HomeEmptyState { appState.selectedTab = .log }
                } else {
                    TimeSeriesChartCard(sessions: sessions, label: "Time Invested",
                                        range: $range, mode: $mode)
                    HomePositions(positions: summary.positions,
                                  activityBuckets: summary.activityBuckets,
                                  activities: activities)
                }
            }
            .padding(Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xxl)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("LOCKEDINMAX")
                .typography(.sectionLabel)
                .foregroundStyle(Theme.accent)
            Spacer()
            Text(dateHeader)
                .typography(.sectionLabel)
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityAddTraits(.isHeader)
    }

    private var dateHeader: String {
        let date = Date.now
        let weekday = date.formatted(.dateTime.weekday(.abbreviated)).uppercased()
        let day = String(Calendar.current.component(.day, from: date))
        let month = date.formatted(.dateTime.month(.abbreviated)).uppercased()
        return "\(weekday) \(day) \(month)"
    }

}

#Preview {
    NavigationStack { HomeView() }
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
        .environment(AppState())
        .preferredColorScheme(.dark)
}
