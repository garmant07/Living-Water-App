import SwiftUI

// A simple outlined container with flat water inside: a glass, a jug, a
// bucket, a tub, a tank on legs, or a pool. Drawn in the same flat,
// no-shading style as the globe.
struct VesselView: View {
    let kind: VesselKind
    /// How full it is, from 0 (empty) to 1 (full).
    let fill: Double
    var lineWidth: CGFloat = 3

    var body: some View {
        Canvas { context, size in
            let frame = CGRect(origin: .zero, size: size).insetBy(dx: lineWidth, dy: lineWidth)
            let outline = kind.outline(in: frame)
            let bounds = outline.boundingRect
            let surface = bounds.maxY - bounds.height * min(max(fill, 0), 1)

            // The water is a plain rectangle, trimmed to the container's shape.
            var water = context
            water.clip(to: outline)
            water.fill(
                Path(CGRect(x: bounds.minX, y: surface, width: bounds.width, height: bounds.maxY - surface)),
                with: .color(Theme.water)
            )

            let stroke = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            context.stroke(outline, with: .color(Theme.globeOutline), style: stroke)
            context.stroke(kind.details(in: frame), with: .color(Theme.globeOutline), style: stroke)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private extension VesselKind {
    /// The part that holds water.
    func outline(in frame: CGRect) -> Path {
        func at(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: frame.minX + frame.width * x, y: frame.minY + frame.height * y)
        }
        var path = Path()

        switch self {
        case .glass:
            path.addLines([at(0.24, 0.10), at(0.76, 0.10), at(0.67, 0.92), at(0.33, 0.92)])
        case .jug:
            path.addLines([
                at(0.40, 0.08), at(0.60, 0.08), at(0.60, 0.24), at(0.80, 0.38),
                at(0.80, 0.92), at(0.20, 0.92), at(0.20, 0.38), at(0.40, 0.24),
            ])
        case .bucket:
            path.addLines([at(0.14, 0.34), at(0.86, 0.34), at(0.73, 0.92), at(0.27, 0.92)])
        case .tub:
            path.move(to: at(0.05, 0.36))
            path.addLine(to: at(0.95, 0.36))
            path.addQuadCurve(to: at(0.78, 0.80), control: at(0.95, 0.80))
            path.addLine(to: at(0.22, 0.80))
            path.addQuadCurve(to: at(0.05, 0.36), control: at(0.05, 0.80))
        case .tank:
            path.addRoundedRect(
                in: CGRect(origin: at(0.22, 0.08), size: CGSize(width: frame.width * 0.56, height: frame.height * 0.50)),
                cornerSize: CGSize(width: frame.width * 0.08, height: frame.width * 0.08)
            )
            return path
        case .pool:
            path.addRoundedRect(
                in: CGRect(origin: at(0.04, 0.42), size: CGSize(width: frame.width * 0.92, height: frame.height * 0.40)),
                cornerSize: CGSize(width: frame.width * 0.04, height: frame.width * 0.04)
            )
            return path
        }

        path.closeSubpath()
        return path
    }

    /// Handles, feet, legs and ladders: lines that don't hold water.
    func details(in frame: CGRect) -> Path {
        func at(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: frame.minX + frame.width * x, y: frame.minY + frame.height * y)
        }
        var path = Path()

        switch self {
        case .glass, .jug:
            break
        case .bucket:
            // The handle
            path.move(to: at(0.14, 0.34))
            path.addQuadCurve(to: at(0.86, 0.34), control: at(0.50, -0.12))
        case .tub:
            // Two feet
            path.move(to: at(0.27, 0.80))
            path.addLine(to: at(0.23, 0.92))
            path.move(to: at(0.73, 0.80))
            path.addLine(to: at(0.77, 0.92))
        case .tank:
            // Legs and a brace
            path.move(to: at(0.30, 0.58))
            path.addLine(to: at(0.22, 0.92))
            path.move(to: at(0.70, 0.58))
            path.addLine(to: at(0.78, 0.92))
            path.move(to: at(0.26, 0.76))
            path.addLine(to: at(0.74, 0.76))
        case .pool:
            // A ladder
            path.move(to: at(0.72, 0.56))
            path.addLine(to: at(0.72, 0.26))
            path.addQuadCurve(to: at(0.78, 0.26), control: at(0.75, 0.18))
            path.move(to: at(0.84, 0.56))
            path.addLine(to: at(0.84, 0.26))
            path.addQuadCurve(to: at(0.90, 0.26), control: at(0.87, 0.18))
            path.move(to: at(0.72, 0.36))
            path.addLine(to: at(0.84, 0.36))
        }
        return path
    }
}

#Preview {
    HStack {
        VesselView(kind: .glass, fill: 0.6)
        VesselView(kind: .jug, fill: 0.6)
        VesselView(kind: .bucket, fill: 0.6)
        VesselView(kind: .tub, fill: 0.6)
        VesselView(kind: .tank, fill: 0.6)
        VesselView(kind: .pool, fill: 0.6)
    }
    .padding()
    .background(Theme.background)
}
