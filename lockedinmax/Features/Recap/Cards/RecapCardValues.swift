import Foundation
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct RecapSessionValue: Identifiable {
    let id: UUID
    let date: Date
    let hours: Double
    let activityID: UUID?
    let activityName: String
    let activityColorHex: String
    let note: String
    let photo: UIImage?
    let photoData: Data?

    init(id: UUID = UUID(), date: Date, hours: Double, activityID: UUID?, activityName: String,
         activityColorHex: String, note: String = "", photo: UIImage? = nil, photoData: Data? = nil) {
        self.id = id
        self.date = date
        self.hours = hours
        self.activityID = activityID
        self.activityName = activityName
        self.activityColorHex = activityColorHex
        self.note = note
        self.photo = photo
        self.photoData = photoData
    }

    init(model: Session, includePhoto: Bool = false) {
        self.init(id: model.id, date: model.date, hours: model.hours,
                  activityID: model.activity?.id, activityName: model.activity?.name ?? "SESSION",
                  activityColorHex: model.activity?.colorHex ?? "#CCFF00", note: model.note,
                  photo: includePhoto ? model.photoData.flatMap(UIImage.init(data:)) : nil,
                  photoData: model.photoData)
    }
}

struct RecapScoreValue: Identifiable {
    let id: UUID
    let date: Date
    let metricName: String
    let value: Double

    init(id: UUID = UUID(), date: Date, metricName: String, value: Double) {
        self.id = id
        self.date = date
        self.metricName = metricName
        self.value = value
    }

    init(model: MetricEntry) {
        self.init(id: model.id, date: model.date, metricName: model.metric?.name ?? "SCORE", value: model.value)
    }
}

struct SessionRecapCardData {
    let session: RecapSessionValue
    let activityHistory: [RecapSessionValue]
    let allSessions: [RecapSessionValue]
    let daySessions: [RecapSessionValue]
    let previousDaySessions: [RecapSessionValue]
    let scores: [RecapScoreValue]
    let caption: String
    let format: RecapCardFormat
    let background: RecapCardBackground
}

struct MarketCloseCardData {
    let date: Date
    let sessions: [RecapSessionValue]
    let previousDaySessions: [RecapSessionValue]
    let scores: [RecapScoreValue]
    let format: RecapCardFormat
}

enum RecapCardFactory {
    static func session(_ selected: Session, allSessions: [Session], scores: [MetricEntry],
                        caption: String, format: RecapCardFormat,
                        background: RecapCardBackground) -> SessionRecapCardData {
        let calendar = Calendar.current
        let activityHistory = allSessions.filter { $0.activity?.id == selected.activity?.id }
            .map { RecapSessionValue(model: $0) }
        let day = allSessions.filter { calendar.isDate($0.date, inSameDayAs: selected.date) }
            .map { RecapSessionValue(model: $0, includePhoto: true) }
        let previousDate = calendar.date(byAdding: .day, value: -1,
                                         to: calendar.startOfDay(for: selected.date)) ?? selected.date
        let previous = allSessions.filter { calendar.isDate($0.date, inSameDayAs: previousDate) }
            .map { RecapSessionValue(model: $0, includePhoto: true) }
        let sameDayScores = scores.filter { calendar.isDate($0.date, inSameDayAs: selected.date) }
            .map(RecapScoreValue.init(model:))
        return SessionRecapCardData(session: RecapSessionValue(model: selected, includePhoto: true),
                                    activityHistory: activityHistory,
                                    allSessions: allSessions.map { RecapSessionValue(model: $0, includePhoto: true) },
                                    daySessions: day, previousDaySessions: previous, scores: sameDayScores,
                                    caption: String(caption.prefix(80)), format: format, background: background)
    }

    static func marketClose(_ date: Date, sessions: [Session], scores: [MetricEntry],
                            format: RecapCardFormat) -> MarketCloseCardData {
        let calendar = Calendar.current
        let day = sessions.filter { calendar.isDate($0.date, inSameDayAs: date) }
            .map { RecapSessionValue(model: $0, includePhoto: true) }
        let previousDate = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date)) ?? date
        let previous = sessions.filter { calendar.isDate($0.date, inSameDayAs: previousDate) }
            .map { RecapSessionValue(model: $0, includePhoto: true) }
        let dayScores = scores.filter { calendar.isDate($0.date, inSameDayAs: date) }
            .map(RecapScoreValue.init(model:))
        return MarketCloseCardData(date: date, sessions: day, previousDaySessions: previous,
                                   scores: dayScores, format: format)
    }
}
