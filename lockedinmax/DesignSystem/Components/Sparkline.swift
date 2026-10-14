import SwiftUI

struct Sparkline: View {
    let values: [Double]
    let color: Color
    var size: CGSize = CGSize(width: 64, height: 24)

    private var points: [CGPoint] {
        guard values.count > 1 else {
            return [CGPoint(x: 0, y: size.height / 2), CGPoint(x: size.width, y: size.height / 2)]
        }
        let minimum = min(0, values.min() ?? 0)
        let maximum = max(minimum + 1, values.max() ?? 1)
        let range = maximum - minimum
        return values.enumerated().map { index, value in
            let x = size.width * CGFloat(index) / CGFloat(values.count - 1)
            let y = size.height - (CGFloat(value - minimum) / CGFloat(range) * size.height)
            return CGPoint(x: x, y: y)
        }
    }

    var body: some View {
        Path { path in
            let points = points
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() { path.addLine(to: point) }
        }
        .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
        Sparkline(values: [0, 1, 0.5, 2, 1.5, 3], color: Theme.accent)
        Sparkline(values: [0, 0, 0, 0], color: Theme.down)
    }
    .padding(Theme.Spacing.lg)
    .background(Theme.background)
}
