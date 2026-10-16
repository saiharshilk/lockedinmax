import Foundation

/// Bounds date and bucket iteration so corrupt or unusually old dates cannot monopolize the UI.
struct LoopGuard {
    static let maximumIterations = 100_000

    private let function: String
    private var iterations = 0
    private var didReportLimit = false

    init(_ function: String) {
        self.function = function
    }

    mutating func next() -> Bool {
        guard iterations < Self.maximumIterations else {
            if !didReportLimit {
                didReportLimit = true
                LoopGuard.recordLimit(function)
            }
            return false
        }
        iterations += 1
        return true
    }

    private static func recordLimit(_ function: String) {
#if DEBUG
        let message = "LoopGuard: \(function) stopped after \(maximumIterations) iterations"
        MessageStore.shared.append(message)
        NSLog("[%@]", message)
#endif
    }

    static var messages: [String] {
#if DEBUG
        MessageStore.shared.snapshot()
#else
        []
#endif
    }

    static func resetMessages() {
#if DEBUG
        MessageStore.shared.reset()
#endif
    }

#if DEBUG
    private final class MessageStore: @unchecked Sendable {
        static let shared = MessageStore()
        private let lock = NSLock()
        private var storage: [String] = []

        func append(_ message: String) {
            lock.lock()
            storage.append(message)
            lock.unlock()
        }

        func snapshot() -> [String] {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }

        func reset() {
            lock.lock()
            storage.removeAll()
            lock.unlock()
        }
    }
#endif
}
