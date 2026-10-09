import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            navigation {
                DesignSystemPreview()
            }
            .tabItem { Label("Home", systemImage: "chart.line.uptrend.xyaxis") }

            navigation {
                StatsView()
            }
            .tabItem { Label("Stats", systemImage: "chart.bar.xaxis") }

            navigation {
                LogView()
            }
            .tabItem { Label("Log", systemImage: "plus.circle") }

            navigation {
                RecapView()
            }
            .tabItem { Label("Recap", systemImage: "rectangle.portrait.on.rectangle.portrait") }
        }
        .tint(Theme.accent)
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
        .onAppear { Theme.configureTabBarAppearance() }
}
