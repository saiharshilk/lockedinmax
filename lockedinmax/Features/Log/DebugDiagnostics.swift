#if DEBUG
import Foundation
import Observation
import SwiftData

struct DebugModelSaveEvent: Identifiable {
    let id = UUID()
    let date: Date
    let phase: String
    let insertedCount: Int
    let updatedCount: Int
    let deletedCount: Int
    var summary: String {
        "\(date.formatted(date: .omitted, time: .standard)) \(phase) +\(insertedCount) ~\(updatedCount) -\(deletedCount)"
    }
}

struct DebugTabChange: Identifiable {
    let id = UUID()
    let date: Date
    let from: AppTab
    let to: AppTab
    let frames: [String]
}

@Observable @MainActor
final class DebugDiagnostics {
    static let shared = DebugDiagnostics()
    private(set) var saveEvents: [DebugModelSaveEvent] = []
    private(set) var modelSaveObserverCount = 0
    private(set) var tabChanges: [DebugTabChange] = []
    private(set) var homeAnalyticsRecomputes = 0
    private(set) var recapRenders = 0
    private(set) var saveEventCount = 0
    private var tokens: [NSObjectProtocol] = []
    private var observedContextID: ObjectIdentifier?

    func observe(_ context: ModelContext) {
        guard !DebugWorkState.isSeeding else { return }
        let contextID = ObjectIdentifier(context)
        guard observedContextID != contextID else { return }
        tokens.forEach { NotificationCenter.default.removeObserver($0) }
        tokens.removeAll()
        observedContextID = contextID
        modelSaveObserverCount = 1
        tokens.append(NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: context, queue: .main) { [weak self] note in
            guard !DebugWorkState.isSeeding, let self else { return }
            let insertedCount = Self.identifierCount(note, key: .insertedIdentifiers)
            let updatedCount = Self.identifierCount(note, key: .updatedIdentifiers)
            let deletedCount = Self.identifierCount(note, key: .deletedIdentifiers)
            Task { @MainActor in
                self.appendEvent(phase: "didSave", insertedCount: insertedCount,
                                 updatedCount: updatedCount, deletedCount: deletedCount)
            }
        })
    }

    func recordTabChange(from: AppTab, to: AppTab) {
        guard from != to else { return }
        let frames = Array(Thread.callStackSymbols.prefix(6))
        tabChanges.insert(DebugTabChange(date: .now, from: from, to: to, frames: frames), at: 0)
        tabChanges = Array(tabChanges.prefix(30))
        print("[Tab] \(from) -> \(to)\n\(frames.joined(separator: "\n"))")
    }

    func recordHomeAnalytics() { homeAnalyticsRecomputes += 1 }
    func recordRecapRender() { recapRenders += 1 }

    private nonisolated static func identifierCount(_ note: Notification,
                                                    key: ModelContext.NotificationKey) -> Int {
        let value = note.userInfo?[key] ?? note.userInfo?[key.rawValue]
        return (value as? Set<PersistentIdentifier>)?.count
            ?? (value as? [PersistentIdentifier])?.count ?? 0
    }

    private func appendEvent(phase: String, insertedCount: Int, updatedCount: Int, deletedCount: Int) {
        saveEventCount += 1
        let event = DebugModelSaveEvent(date: .now, phase: phase, insertedCount: insertedCount,
                                        updatedCount: updatedCount, deletedCount: deletedCount)
        saveEvents.insert(event, at: 0)
        saveEvents = Array(saveEvents.prefix(30))
        print("[ModelContext] \(event.summary)")
    }
}
#endif
