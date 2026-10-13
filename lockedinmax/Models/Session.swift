import Foundation
import SwiftData

@Model
final class Session {
    var id: UUID
    var date: Date
    var hours: Double
    var note: String
    @Attribute(.externalStorage) var photoData: Data?
    var activity: Activity?

    init(date: Date = .now, hours: Double, note: String = "", photoData: Data? = nil,
         activity: Activity? = nil) {
        self.id = UUID()
        self.date = date
        self.hours = hours
        self.note = note
        self.photoData = photoData
        self.activity = activity
    }
}
