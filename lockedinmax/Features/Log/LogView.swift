import SwiftData
import SwiftUI

struct LogView: View {
    @State private var isScore = false

    var body: some View {
        List {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                Text("Log").typography(.title).foregroundStyle(Theme.textPrimary)
                LogSegmentControl(isScore: $isScore)
                if isScore {
                    ScoreLogForm()
                } else {
                    SessionLogForm()
                }
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Theme.background)

            Section {
                RecentLogs()
                    .listRowBackground(Theme.background)
                    .listRowSeparatorTint(Theme.hairline)
            } header: {
                SectionHeader(title: "RECENT")
            }
#if DEBUG
            Section {
                DebugDataTools()
                    .listRowBackground(Theme.background)
                    .listRowSeparator(.hidden)
            }
#endif
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
        .tint(Theme.accent)
    }
}

#Preview {
    NavigationStack { LogView() }
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
        .preferredColorScheme(.dark)
}
