//
//  CarCoachApp.swift
//  CarCoach
//

import Foundation
import SwiftData
import SwiftUI

@main
struct CarCoachApp: App {
    private let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            QuestionProgressRecord.self,
            ExamAttemptRecord.self,
            UserSettingsRecord.self
        ])
        let persistentConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [persistentConfig])
        } catch {
            removeIncompatibleStoreFiles()
            do {
                return try ModelContainer(for: schema, configurations: [persistentConfig])
            } catch {
                let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                do {
                    return try ModelContainer(for: schema, configurations: [fallbackConfig])
                } catch {
                    preconditionFailure("Không thể khởi tạo ModelContainer dự phòng: \(error)")
                }
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }

    private static func removeIncompatibleStoreFiles() {
        let fileManager = FileManager.default
        guard let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        let storeFilenames = ["default.store", "default.store-shm", "default.store-wal"]
        for name in storeFilenames {
            let fileURL = supportDirectory.appendingPathComponent(name)
            if fileManager.fileExists(atPath: fileURL.path) {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
}
