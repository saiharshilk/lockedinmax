import Foundation
import SwiftData

@Model
final class MetricEntry {
    var id: UUID
    var date: Date
    var value: Double
    @Attribute(.externalStorage) var screenshotData: Data?
    var metric: Metric?

    init(date: Date = .now, value: Double, screenshotData: Data? = nil, metric: Metric? = nil) {
        self.id = UUID()
        self.date = date
        self.value = value
        self.screenshotData = screenshotData
        self.metric = metric
    }
}
