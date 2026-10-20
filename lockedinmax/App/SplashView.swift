import SwiftUI

struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onFinished: (_ reduceMotion: Bool) -> Void
    @State private var drawsLine = false

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("LOCKEDINMAX")
                .typography(.sectionLabel)
                .tracking(4)
                .foregroundStyle(Theme.accent)
                .accessibilityAddTraits(.isHeader)
            RisingLineShape(progress: drawsLine ? 1 : 0)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .frame(width: 180, height: 42)
                .accessibilityHidden(true)
            Text("Your time is the asset.")
                .typography(.caption)
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .task {
            if reduceMotion {
                drawsLine = true
                try? await Task.sleep(for: .milliseconds(400))
            } else {
                withAnimation(.easeOut(duration: 0.55)) { drawsLine = true }
                try? await Task.sleep(for: .milliseconds(900))
            }
            guard !Task.isCancelled else { return }
            onFinished(reduceMotion)
        }
    }
}

private struct RisingLineShape: Shape {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let points = [
            CGPoint(x: rect.minX, y: rect.maxY * 0.82),
            CGPoint(x: rect.width * 0.24, y: rect.height * 0.63),
            CGPoint(x: rect.width * 0.43, y: rect.height * 0.72),
            CGPoint(x: rect.width * 0.65, y: rect.height * 0.36),
            CGPoint(x: rect.maxX, y: rect.minY + 3)
        ]
        let segments = max(1, Int(ceil(progress * CGFloat(points.count - 1))))
        let endIndex = min(points.count - 1, segments)
        var path = Path()
        path.move(to: points[0])
        if endIndex > 0 {
            for index in 1...endIndex {
                let fraction = min(1, progress * CGFloat(points.count - 1) - CGFloat(index - 1))
                let previous = points[index - 1]
                let current = points[index]
                path.addLine(to: CGPoint(x: previous.x + (current.x - previous.x) * fraction,
                                         y: previous.y + (current.y - previous.y) * fraction))
                if fraction < 1 { break }
            }
        }
        return path
    }
}
