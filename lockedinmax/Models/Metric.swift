import Foundation
import SwiftData

@Model
final class Metric {
    var id: UUID
    var name: String
    var unit: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \MetricEntry.metric)
    var entries: [MetricEntry] = []

    init(name: String, unit: String = "", createdAt: Date = .now) {
        self.id = UUID()
        self.name = name
        self.unit = unit
        self.createdAt = createdAt
    }
}
