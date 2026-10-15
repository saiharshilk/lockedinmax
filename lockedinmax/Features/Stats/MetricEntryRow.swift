import SwiftUI

struct MetricEntryRow: View {
    let entry: MetricEntry
    let unit: String
    let onEdit: () -> Void
    let onPhoto: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Button(action: onEdit) {
                HStack {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(Formatters.metric(entry.value, unit: unit)).typography(.rowTitle).foregroundStyle(Theme.textPrimary)
                        Text(entry.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()))
                            .typography(.caption).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
            if let data = entry.screenshotData, let image = UIImage(data: data) {
                Button(action: onPhoto) {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small))
                }.buttonStyle(.plain).accessibilityLabel("View score screenshot")
            }
        }.padding(.vertical, Theme.Spacing.sm).overlay(alignment: .bottom) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
    }
}
