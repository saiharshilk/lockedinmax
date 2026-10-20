//
//  lockedinmaxApp.swift
//  lockedinmax
//
//  Created by Sai Harshil Konchada on 10/8/26.
//

import SwiftUI
import SwiftData
import CoreText

@main
struct lockedinmaxApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Activity.self,
            Session.self,
            Metric.self,
            MetricEntry.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var showSplash = true

    init() {
        Self.registerBundledFonts()
        Theme.configureTabBarAppearance()
    }

    private static func registerBundledFonts() {
        let fontNames = [
            "JetBrainsMono-Regular.ttf",
            "JetBrainsMono-Medium.ttf",
            "JetBrainsMono-SemiBold.ttf",
            "PlayfairDisplay[wght].ttf"
        ]
        let urls = fontNames.compactMap { filename in
            Bundle.main.url(forResource: filename, withExtension: nil, subdirectory: "Resources/Fonts")
                ?? Bundle.main.url(forResource: filename, withExtension: nil, subdirectory: "Fonts")
                ?? Bundle.main.url(forResource: filename, withExtension: nil)
        }
        guard !urls.isEmpty else { return }
        CTFontManagerRegisterFontURLs(urls as CFArray, .process, true, nil)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                if showSplash {
                    SplashView { reduceMotion in
                        if reduceMotion { showSplash = false }
                        else { withAnimation(.easeOut(duration: 0.25)) { showSplash = false } }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}
