import SwiftData
import SwiftUI

struct RootView: View {
    @State private var appState = AppState()

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            navigation {
                HomeView()
            }
            .tag(AppTab.home)
            .tabItem { Label("Home", systemImage: "chart.line.uptrend.xyaxis") }

            navigation {
                StatsView()
            }
            .tag(AppTab.stats)
            .tabItem { Label("Stats", systemImage: "chart.bar.xaxis") }

            navigation {
                LogView()
            }
            .tag(AppTab.log)
            .tabItem { Label("Log", systemImage: "plus.circle") }

            navigation {
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
    }

    private func navigation<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background.ignoresSafeArea())
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
