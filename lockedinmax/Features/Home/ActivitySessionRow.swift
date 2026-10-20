import SwiftUI

struct ActivitySessionRow: View {
    let session: Session
    let onEdit: () -> Void
    let onPhoto: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(Formatters.hours(session.hours))
                        .typography(.rowTitle).foregroundStyle(Theme.textPrimary)
                    if !session.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(session.note).typography(.caption).foregroundStyle(Theme.textSecondary)
                            .lineLimit(2).multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Edit session")
            if let data = session.photoData, let image = UIImage(data: data) {
                Button(action: onPhoto) {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View session photo")
            }
        }
        .padding(.vertical, Theme.Spacing.sm)
        .accessibilityElement(children: .contain)
    }
}

struct SessionPhotoViewer: View {
    let data: Data
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)
        .accessibilityLabel("Tap to dismiss photo")
    }
}

#Preview {
    ActivitySessionRow(session: Session(hours: 1.5, note: "Focused review"), onEdit: {}, onPhoto: {})
        .padding(Theme.Spacing.lg).background(Theme.background)
}
