import Foundation
import SwiftData

@Model
final class Activity {
    var id: UUID
    var name: String
    var colorHex: String
    var iconName: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Session.activity)
    var sessions: [Session] = []

    init(name: String, colorHex: String, iconName: String, createdAt: Date = .now) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
        self.createdAt = createdAt
    }
}
