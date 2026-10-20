import PhotosUI
import SwiftUI

struct PhotoInput: View {
    let title: String
    let large: Bool
    @Binding var data: Data?
    @State private var selection: PhotosPickerItem?
    @Binding var isLoading: Bool
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            PhotosPicker(selection: $selection, matching: .images) {
                Group {
                    if let data, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable().scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: large ? 240 : 100)
                    } else {
                        VStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "photo.badge.plus").typography(.title)
                            Text(isLoading ? "Loading image…" : title).typography(.caption)
                        }
                        .frame(maxWidth: .infinity, minHeight: large ? 180 : Theme.minimumTapHeight)
                    }
                }
                .foregroundStyle(Theme.textSecondary)
                .padding(Theme.Spacing.md)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.medium)
                        .stroke(Theme.hairline, style: StrokeStyle(lineWidth: Theme.borderWidth, dash: [6, 4]))
                }
            }
            .buttonStyle(.plain)
            .frame(minHeight: Theme.minimumTapHeight)
            .accessibilityLabel(title)
            if data != nil || isLoading {
                Button("Remove image", systemImage: "xmark.circle") {
                    selection = nil
                    data = nil
                }
                .typography(.caption).foregroundStyle(Theme.textSecondary)
            }
        }
        .task(id: selection) {
            guard let selected = selection else { isLoading = false; return }
            isLoading = true
            defer { isLoading = false }
            do {
                guard let loaded = try await selected.loadTransferable(type: Data.self),
                      UIImage(data: loaded) != nil else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                try Task.checkCancellation()
                data = loaded
            } catch is CancellationError {
                // Removing or replacing a selection cancels the previous load.
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = "Could not load this image. Please choose another photo."
            }
        }
        .onChange(of: data) { _, newValue in
            if newValue == nil { selection = nil }
        }
        .alert("Image unavailable", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }
}

#Preview {
    PhotoInput(title: "Add screenshot (optional)", large: true, data: .constant(nil),
               isLoading: .constant(false))
        .padding(Theme.Spacing.lg).background(Theme.background).preferredColorScheme(.dark)
}
