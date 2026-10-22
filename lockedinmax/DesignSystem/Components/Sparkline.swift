import SwiftUI

struct Sparkline: View {
    let values: [Double]
    let color: Color
    var size: CGSize = CGSize(width: 64, height: 24)

    private var points: [CGPoint] {
        let finiteValues = values.map { $0.isFinite ? max(0, $0) : 0 }
        guard finiteValues.count > 1 else {
            return [CGPoint(x: 0, y: size.height / 2), CGPoint(x: size.width, y: size.height / 2)]
        }
        let maximum = finiteValues.max() ?? 0
        guard maximum > 0 else {
            return [CGPoint(x: 0, y: size.height / 2), CGPoint(x: size.width, y: size.height / 2)]
        }
        let topInset: CGFloat = 2
        let bottomInset: CGFloat = 2
        let plotHeight = max(1, size.height - topInset - bottomInset)
        let points = finiteValues.enumerated().map { index, value in
            let x = size.width * CGFloat(index) / CGFloat(finiteValues.count - 1)
            let y = size.height - bottomInset - CGFloat(value / maximum) * plotHeight
            return CGPoint(x: x, y: y)
        }

        // A lone active bucket still reads as a time series, not a one-segment slash.
        guard finiteValues.filter({ $0 > 0 }).count == 1 else { return points }
        return points.enumerated().map { index, point in
            CGPoint(x: point.x, y: index == points.count - 1
                     ? size.height - bottomInset - plotHeight
                     : size.height - bottomInset)
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
