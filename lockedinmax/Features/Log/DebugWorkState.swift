#if DEBUG
import Foundation

struct SampleLoadTimings: CustomStringConvertible {
    let generationMilliseconds: Double
    let insertionMilliseconds: Double
    let saveMilliseconds: Double
    var totalMilliseconds: Double { generationMilliseconds + insertionMilliseconds + saveMilliseconds }

    var description: String {
        String(format: "generation %.1f ms · insertion %.1f ms · save %.1f ms · total %.1f ms",
               generationMilliseconds, insertionMilliseconds, saveMilliseconds, totalMilliseconds)
    }
}

/// Deliberately not Observable: reading the seed flag must not subscribe views to writes during batch inserts.
enum DebugWorkState {
    private static let lock = NSLock()
    private static var seeding = false
    private static var timings: SampleLoadTimings?
    private static var refreshVersion = 0

    static var isSeeding: Bool {
        lock.lock()
        defer { lock.unlock() }
        return seeding
    }

    static var generation: Int {
        lock.lock()
        defer { lock.unlock() }
        return refreshVersion
    }

    static var lastSampleLoadTimings: SampleLoadTimings? {
        lock.lock()
        defer { lock.unlock() }
        return timings
    }

    static func beginSeeding() {
        lock.lock()
        seeding = true
        lock.unlock()
    }

    static func finishSeeding(timings newTimings: SampleLoadTimings?) {
        lock.lock()
        timings = newTimings
        refreshVersion += 1
        seeding = false
        lock.unlock()
    }
}
#endif
