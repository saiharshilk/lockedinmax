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
    @State private var didRunAutoSampleLoad = false
    @State private var didSeedCalculus = false
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
#if DEBUG
        .background {
            GeometryReader { geometry in
                Color.clear.onAppear { DebugDiagnostics.shared.recordTabContainerFrame(geometry.frame(in: .global)) }
                    .onChange(of: geometry.frame(in: .global)) { _, frame in
                        DebugDiagnostics.shared.recordTabContainerFrame(frame)
                    }
            }
        }
#endif
        .background(Theme.background.ignoresSafeArea())
        .overlay {
#if DEBUG
            GeometryReader { geometry in
                Color.clear.onAppear { DebugDiagnostics.shared.recordRootViewFrame(geometry.frame(in: .global)) }
                    .onChange(of: geometry.frame(in: .global)) { _, frame in
                        DebugDiagnostics.shared.recordRootViewFrame(frame)
                    }
            }
#endif
        }
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
            if let index = arguments.firstIndex(of: "-startTab"), arguments.indices.contains(index + 1),
               let tab = AppTab(argumentValue: arguments[index + 1]) {
                appState.selectedTab = tab
            }
            if arguments.contains("-seedCalculus") && !didSeedCalculus {
                didSeedCalculus = true
                do { try DebugWorkState.seedCalculus(in: modelContext) }
                catch { NSLog("[CalculusSeed] FAILED: %@", error.localizedDescription) }
            }
            if arguments.contains("-autoLoadSample") && !didRunAutoSampleLoad {
                didRunAutoSampleLoad = true
                await runAutoSampleLoad()
            }
            if arguments.contains("--sample-data-self-check") && !didRunSampleDataSelfCheck {
                didRunSampleDataSelfCheck = true
                NSLog("[SampleDataSelfCheck] %@", SampleData.runSampleDataSelfCheck())
            }
            if arguments.contains("--analytics-sweep") {
                NSLog("[AnalyticsSweepArgument] %@", AnalyticsSweep.runAnalyticsSweep().description)
            }
            if arguments.contains("--stats-self-check") {
                appState.selectedTab = .stats
                NSLog("[StatsSelfCheck] %@", StatsAnalyticsSelfCheck.run())
            }
            if arguments.contains("--check-recap-cards") {
                NSLog("[RecapCardCheck] %@", RecapCardChecks.run())
            }
            if arguments.contains("--recap-self-test") {
                appState.selectedTab = .log
            }
            if arguments.contains("--churn-test") && !didRunChurnTest {
                didRunChurnTest = true
                await DebugDataOperations.launchChurnTestIfRequested(in: modelContext, appState: appState)
            }
        }
#endif
    }

#if DEBUG
    @MainActor private func runAutoSampleLoad() async {
        await appState.debugTaskRunner.loadSamples(in: modelContext, appState: appState, replacing: true)
    }
#endif

    private func navigation<Content: View>(path: Binding<NavigationPath>,
                                            @ViewBuilder content: () -> Content) -> some View {
        NavigationStack(path: path) {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background.ignoresSafeArea())
#if os(iOS)
                .toolbarBackground(Theme.background, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(.hidden, for: .tabBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
#endif
        }
        .background(Theme.background.ignoresSafeArea())
    }
}

#if DEBUG
private extension AppTab {
    init?(argumentValue: String) {
        switch argumentValue.lowercased() {
        case "home": self = .home
        case "stats": self = .stats
        case "log": self = .log
        case "recap": self = .recap
        default: return nil
        }
    }
}

private struct RootContainerFrameKey: PreferenceKey {
    static var defaultValue = CGRect.zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}
#endif

#Preview {
    RootView()
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
        .onAppear { Theme.configureTabBarAppearance() }
}
