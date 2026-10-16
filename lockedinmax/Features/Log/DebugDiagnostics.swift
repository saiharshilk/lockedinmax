#if DEBUG
import Foundation
import Observation
import SwiftData

struct DebugModelSaveEvent: Identifiable {
    let id = UUID()
    let date: Date
    let phase: String
    let inserted: [String]
    let updated: [String]
    let deleted: [String]
    var summary: String {
        "\(date.formatted(date: .omitted, time: .standard)) \(phase) +[\(inserted.joined(separator: ", "))] ~[\(updated.joined(separator: ", "))] -[\(deleted.joined(separator: ", "))]"
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
    private(set) var tabChanges: [DebugTabChange] = []
    private(set) var homeAnalyticsRecomputes = 0
    private(set) var recapRenders = 0
    private(set) var saveEventCount = 0
    private var tokens: [NSObjectProtocol] = []
    private var observedContext: ModelContext?
    private var previousSessionHours: [UUID: Double] = [:]

    func observe(_ context: ModelContext) {
        guard !DebugWorkState.isSeeding else { return }
        guard observedContext !== context else { return }
        tokens.forEach { NotificationCenter.default.removeObserver($0) }
        tokens.removeAll()
        observedContext = context
        if let currentSessions = try? context.fetch(FetchDescriptor<Session>()) {
            previousSessionHours = currentSessions.reduce(into: [:]) { $0[$1.id] = $1.hours }
        } else {
            previousSessionHours = [:]
        }
        tokens.append(NotificationCenter.default.addObserver(forName: ModelContext.willSave, object: context, queue: .main) { [weak self, weak context] note in
            guard !DebugWorkState.isSeeding, let self, let context else { return }
            Task { @MainActor in self.recordWillSave(note, context: context) }
        })
        tokens.append(NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: context, queue: .main) { [weak self, weak context] note in
            guard !DebugWorkState.isSeeding, let self, let context else { return }
            Task { @MainActor in self.recordDidSave(note, context: context) }
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

    private func recordWillSave(_ note: Notification, context: ModelContext) {
        guard !DebugWorkState.isSeeding else { return }
        appendEvent(phase: "willSave", inserted: describe(context.insertedModelsArray),
                    updated: describe(context.changedModelsArray, compareSessionHours: true),
                    deleted: describe(context.deletedModelsArray))
    }

    private func recordDidSave(_ note: Notification, context: ModelContext) {
        guard !DebugWorkState.isSeeding else { return }
        let inserted = models(note, key: .insertedIdentifiers, context: context)
        let updated = models(note, key: .updatedIdentifiers, context: context)
        let deleted = models(note, key: .deletedIdentifiers, context: context)
        appendEvent(phase: "didSave", inserted: describe(inserted),
                    updated: describe(updated, compareSessionHours: true), deleted: describe(deleted))
        for model in inserted + updated {
            if let session = model as? Session { previousSessionHours[session.id] = session.hours }
        }
        for model in deleted {
            if let session = model as? Session { previousSessionHours.removeValue(forKey: session.id) }
        }
    }

    private func models(_ note: Notification, key: ModelContext.NotificationKey,
                        context: ModelContext) -> [any PersistentModel] {
        let value = note.userInfo?[key] ?? note.userInfo?[key.rawValue]
        let ids = (value as? Set<PersistentIdentifier>).map(Array.init)
            ?? (value as? [PersistentIdentifier]) ?? []
        return ids.map { context.model(for: $0) }
    }

    private func describe(_ models: [any PersistentModel], compareSessionHours: Bool = false) -> [String] {
        models.map { model in
            let typeName = String(describing: type(of: model))
            let id = String(describing: model.persistentModelID)
            guard let session = model as? Session else { return "\(typeName)(\(id))" }
            if compareSessionHours {
                let before = previousSessionHours[session.id].map(String.init) ?? "new"
                return "Session(\(id), \(before)->\(session.hours)h)"
            }
            return "Session(\(id), \(session.hours)h)"
        }
    }

    private func appendEvent(phase: String, inserted: [String], updated: [String], deleted: [String]) {
        saveEventCount += 1
        let event = DebugModelSaveEvent(date: .now, phase: phase, inserted: inserted,
                                        updated: updated, deleted: deleted)
        saveEvents.insert(event, at: 0)
        saveEvents = Array(saveEvents.prefix(30))
        print("[ModelContext] \(event.summary)")
    }
}
#endif
