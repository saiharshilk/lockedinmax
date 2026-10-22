import SwiftData
import SwiftUI

struct LogView: View {
    @Environment(AppState.self) private var appState
    @State private var isScore = false

    var body: some View {
        List {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                Text("Log").typography(.title).foregroundStyle(Theme.textPrimary)
                    .padding(.top, Theme.Spacing.md)
                    .accessibilityAddTraits(.isHeader)
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
                SectionHeader(title: "RECENT").accessibilityAddTraits(.isHeader)
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
        .tabBarClearance()
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .noScrollEdgeEffect()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .tint(Theme.accent)
        .onAppear(perform: consumeScoreRequest)
        .onChange(of: appState.logScoreRequested) { _, requested in
            if requested { consumeScoreRequest() }
        }
#if DEBUG
        .overlay {
            if ProcessInfo.processInfo.arguments.contains("--recap-self-test") {
                DebugDataTools().frame(width: 1, height: 1).hidden()
            }
        }
#endif
    }

    private func consumeScoreRequest() {
        guard appState.logScoreRequested else { return }
        isScore = true
        appState.logScoreRequested = false
    }
}

#Preview {
    NavigationStack { LogView() }
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
        .environment(AppState())
        .preferredColorScheme(.dark)
}
