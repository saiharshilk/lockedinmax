import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var appState = AppState()
    @State private var homePath = NavigationPath()
    @State private var statsPath = NavigationPath()
    @State private var logPath = NavigationPath()
    @State private var recapPath = NavigationPath()
#if DEBUG
    @State private var didRunSampleDataSelfCheck = false
    @State private var didRunChurnTest = false
#endif

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            navigation(path: $homePath) {
                HomeView()
            }
            .tag(AppTab.home)
            .tabItem { Label("Home", systemImage: "chart.line.uptrend.xyaxis") }

            navigation(path: $statsPath) {
                StatsView()
            }
            .tag(AppTab.stats)
            .tabItem { Label("Stats", systemImage: "chart.bar.xaxis") }

            navigation(path: $logPath) {
                LogView()
            }
            .tag(AppTab.log)
            .tabItem { Label("Log", systemImage: "plus.circle") }

            navigation(path: $recapPath) {
                RecapView()
            }
            .tag(AppTab.recap)
            .tabItem { Label("Recap", systemImage: "rectangle.portrait.on.rectangle.portrait") }
        }
        .tint(Theme.accent)
        .environment(appState)
        .foregroundStyle(Theme.textPrimary)
        .background(Theme.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .onChange(of: appState.navigationResetVersion) { _, _ in
            homePath = NavigationPath()
            statsPath = NavigationPath()
            logPath = NavigationPath()
            recapPath = NavigationPath()
        }
#if DEBUG
        .task {
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--sample-data-self-check") && !didRunSampleDataSelfCheck {
                didRunSampleDataSelfCheck = true
                NSLog("[SampleDataSelfCheck] %@", SampleData.runSampleDataSelfCheck())
            }
            if arguments.contains("--analytics-sweep") {
                NSLog("[AnalyticsSweepArgument] %@", AnalyticsSweep.runAnalyticsSweep().description)
            }
            if arguments.contains("--stats-self-check") {
                NSLog("[StatsSelfCheck] %@", StatsAnalyticsSelfCheck.run())
            }
            if arguments.contains("--churn-test") && !didRunChurnTest {
                didRunChurnTest = true
                await DebugDataOperations.launchChurnTestIfRequested(in: modelContext, appState: appState)
            }
        }
#endif
    }

    private func navigation<Content: View>(path: Binding<NavigationPath>,
                                            @ViewBuilder content: () -> Content) -> some View {
        NavigationStack(path: path) {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background)
#if os(iOS)
                .toolbarBackground(Theme.background, for: .navigationBar, .tabBar)
                .toolbarBackground(.visible, for: .navigationBar, .tabBar)
                .toolbarColorScheme(.dark, for: .navigationBar, .tabBar)
#endif
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
        .onAppear { Theme.configureTabBarAppearance() }
}
