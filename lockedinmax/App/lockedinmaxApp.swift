//
//  lockedinmaxApp.swift
//  lockedinmax
//
//  Created by Sai Harshil Konchada on 10/8/26.
//

import SwiftUI
import SwiftData

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

    init() {
        Theme.configureTabBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}
