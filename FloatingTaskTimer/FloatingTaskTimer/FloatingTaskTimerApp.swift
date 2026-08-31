//
//  FloatingTaskTimerApp.swift
//  FloatingTaskTimer
//
//  Created by Yuying Wang on 31/8/2026.
//

import SwiftUI
import SwiftData
import OSLog

@main
struct FloatingTaskTimerApp: App {
    private static let logger = Logger(
        subsystem: "whywhy.FloatingTaskTimer",
        category: "Persistence"
    )

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            PersistedTaskSession.self,
        ])
        let modelConfiguration = ModelConfiguration(
            "TaskSessions",
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            logger.error("Could not open the persistent store: \(error.localizedDescription, privacy: .public)")

            do {
                let fallbackConfiguration = ModelConfiguration(
                    "TaskSessionsFallback",
                    schema: schema,
                    isStoredInMemoryOnly: true
                )
                return try ModelContainer(for: schema, configurations: [fallbackConfiguration])
            } catch {
                fatalError("Could not create fallback ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
