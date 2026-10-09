import SwiftUI
import simd

// A flat, hand-drawn-style globe: plain sea, plain land, white outlines and
// white dots. No shading and no satellite pictures. It is drawn by the app
// itself from a small file of coastlines (Data/land.json), so it works
// without an internet connection.

/// Where the globe is being looked at from.
struct GlobeCamera: Equatable {
    /// The longitude and latitude at the middle of the view, in degrees.
    var longitude: Double
    var latitude: Double
    /// 1 shows the whole globe. Bigger numbers move in closer.
    var zoom: Double = 1

    static let zoomRange: ClosedRange<Double> = 1...4
}

struct FlatGlobe: View {
    let communities: [Community]
    var selectedID: String? = nil
    /// Joins the dots with thin lines, in order. Used on the Journey tab.
    var connectDots = false
    /// false makes a still picture that ignores touches.
    var interactive = true
    @Binding var camera: GlobeCamera
    /// Called the moment a finger starts moving the globe.
    var onTouch: () -> Void = {}
    var onSelect: (Community) -> Void = { _ in }

    @State private var dragStart: GlobeCamera?
    @State private var zoomStart: Double?

    var body: some View {
        GeometryReader { geometry in
            let projection = GlobeProjection(camera: camera, size: geometry.size)

            ZStack {
                Canvas { context, _ in
                    draw(in: &context, projection: projection)
                }
                .accessibilityHidden(true)

                ForEach(communities) { community in
                    let spot = projection.view(community.unitVector)
                    // Dots on the far side of the globe are hidden.
                    let isVisible = spot.z > 0.03

                    Button {
                        onSelect(community)
                    } label: {
                        GlobeDot(peopleServed: community.peopleServed, isSelected: community.id == selectedID)
                    }
                    .buttonStyle(.plain)
                    .position(projection.point(spot))
                    .opacity(isVisible ? 1 : 0)
                    .allowsHitTesting(isVisible)
                    .accessibilityHidden(!isVisible)
                    .accessibilityLabel("\(community.name), \(Format.number(community.peopleServed)) people served")
                }
            }
            .contentShape(Rectangle())
            .gesture(interactive ? spinAndZoom(radius: projection.radius) : nil)
        }
        .clipped()
        .allowsHitTesting(interactive)
    }

    private func draw(in context: inout GraphicsContext, projection: GlobeProjection) {
        let disc = Path(ellipseIn: CGRect(
            x: projection.center.x - projection.radius,
            y: projection.center.y - projection.radius,
            width: projection.radius * 2,
            height: projection.radius * 2
        ))
        context.fill(disc, with: .color(Theme.globeSea))

        var land = Path()
        for ring in LandShapes.rings {
            projection.addRing(ring, to: &land)
        }
        context.fill(land, with: .color(Theme.globeLand), style: FillStyle(eoFill: true))
        context.stroke(land, with: .color(Theme.globeOutline), style: StrokeStyle(lineWidth: 1.2, lineJoin: .round))

        if connectDots, communities.count > 1 {
            var lines = Path()
            for (from, to) in zip(communities, communities.dropFirst()) {
                projection.addArc(from: from.unitVector, to: to.unitVector, to: &lines)
            }
            context.stroke(lines, with: .color(Theme.globeOutline.opacity(0.8)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 5]))
        }

        context.stroke(disc, with: .color(Theme.globeOutline), lineWidth: 2)
    }

    /// Drag to spin, pinch to zoom.
    private func spinAndZoom(radius: Double) -> some Gesture {
        let spin = DragGesture(minimumDistance: 2)
            .onChanged { value in
                if dragStart == nil {
                    dragStart = camera
                    onTouch()
                }
                guard let start = dragStart else { return }
                let degreesPerPoint = (180 / Double.pi) / radius
                camera.longitude = wrapDegrees(start.longitude - value.translation.width * degreesPerPoint)
                camera.latitude = min(max(start.latitude + value.translation.height * degreesPerPoint, -80), 80)
            }
            .onEnded { _ in dragStart = nil }

        let zoom = MagnifyGesture()
            .onChanged { value in
                if zoomStart == nil {
                    zoomStart = camera.zoom
                    onTouch()
                }
                let wanted = (zoomStart ?? 1) * value.magnification
                camera.zoom = min(max(wanted, GlobeCamera.zoomRange.lowerBound), GlobeCamera.zoomRange.upperBound)
            }
            .onEnded { _ in zoomStart = nil }

        return spin.simultaneously(with: zoom)
    }
}

/// Keeps a longitude between -180 and 180.
func wrapDegrees(_ degrees: Double) -> Double {
    var value = (degrees + 180).truncatingRemainder(dividingBy: 360)
    if value < 0 { value += 360 }
    return value - 180
}

// One white dot. Bigger dots mean more people served.
private struct GlobeDot: View {
    let peopleServed: Int
    let isSelected: Bool

    /// 9 points for the smallest projects up to 16 for the largest.
    private var size: CGFloat {
        CGFloat(min(max(9 + Double(peopleServed).squareRoot() / 65 * 7, 9), 16))
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: size, height: size)
            if isSelected {
                Circle()
                    .stroke(.white, lineWidth: 2)
                    .frame(width: size + 12, height: size + 12)
            }
        }
        // 44 points is the smallest comfortable target for a thumb.
        .frame(width: 44, height: 44)
        .contentShape(Circle())
    }
}

// MARK: The math that turns a round Earth into a flat picture

extension Community {
    /// This community's position as a point on a ball one unit across.
    var unitVector: SIMD3<Double> {
        GlobeProjection.unitVector(latitude: latitude, longitude: longitude)
    }
}

struct GlobeProjection {
    let center: CGPoint
    let radius: Double
    private let east: SIMD3<Double>
    private let north: SIMD3<Double>
    private let forward: SIMD3<Double>

    init(camera: GlobeCamera, size: CGSize) {
        center = CGPoint(x: size.width / 2, y: size.height / 2)
        radius = max((min(size.width, size.height) / 2 - 4) * camera.zoom, 1)

        let lat = camera.latitude * .pi / 180
        let lon = camera.longitude * .pi / 180
        forward = SIMD3(cos(lat) * cos(lon), cos(lat) * sin(lon), sin(lat))
        east = SIMD3(-sin(lon), cos(lon), 0)
        north = SIMD3(-sin(lat) * cos(lon), -sin(lat) * sin(lon), cos(lat))
    }

    static func unitVector(latitude: Double, longitude: Double) -> SIMD3<Double> {
        let lat = latitude * .pi / 180
        let lon = longitude * .pi / 180
        return SIMD3(cos(lat) * cos(lon), cos(lat) * sin(lon), sin(lat))
    }

    /// Turns a point on the Earth into: x across, y up, z toward the viewer.
    /// z below zero means the point is on the far side.
    func view(_ vector: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(simd_dot(vector, east), simd_dot(vector, north), simd_dot(vector, forward))
    }

    /// Where a viewed point lands on the screen.
    func point(_ viewed: SIMD3<Double>) -> CGPoint {
        CGPoint(x: center.x + radius * viewed.x, y: center.y - radius * viewed.y)
    }

    /// Adds one coastline to the drawing, keeping only the part facing the
    /// viewer and following the globe's edge where the coast goes behind it.
    func addRing(_ ring: [SIMD3<Double>], to path: inout Path) {
        let viewed = ring.map(view)
        guard let start = viewed.firstIndex(where: { $0.z > 0 }) else { return }
        let count = viewed.count
        var exitAngle: Double?

        path.move(to: point(viewed[start]))
        for step in 1...count {
            let a = viewed[(start + step - 1) % count]
            let b = viewed[(start + step) % count]

            switch (a.z > 0, b.z > 0) {
            case (true, true):
                path.addLine(to: point(b))
            case (true, false):
                let edge = edgeCrossing(a, b)
                path.addLine(to: point(edge))
                exitAngle = atan2(edge.y, edge.x)
            case (false, true):
                let edge = edgeCrossing(a, b)
                if let exitAngle {
                    addEdgeArc(from: exitAngle, to: atan2(edge.y, edge.x), to: &path)
                }
                path.addLine(to: point(edge))
                path.addLine(to: point(b))
                exitAngle = nil
            case (false, false):
                break
            }
        }
        path.closeSubpath()
    }

    /// Adds the shortest path over the globe between two places.
    func addArc(from: SIMD3<Double>, to: SIMD3<Double>, to path: inout Path) {
        let angle = acos(min(max(simd_dot(from, to), -1), 1))
        guard angle > 0.0001 else { return }
        let steps = max(Int(angle / 0.05), 2)
        var penDown = false

        for step in 0...steps {
            let t = Double(step) / Double(steps)
            let along = (sin((1 - t) * angle) * from + sin(t * angle) * to) / sin(angle)
            let viewed = view(along)
            if viewed.z > 0 {
                if penDown {
                    path.addLine(to: point(viewed))
                } else {
                    path.move(to: point(viewed))
                    penDown = true
                }
            } else {
                penDown = false
            }
        }
    }

    /// The spot on the globe's edge where a line slips from front to back.
    private func edgeCrossing(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> SIMD3<Double> {
        let t = a.z / (a.z - b.z)
        let crossing = a + t * (b - a)
        let length = (crossing.x * crossing.x + crossing.y * crossing.y).squareRoot()
        guard length > 1e-9 else { return SIMD3(1, 0, 0) }
        return SIMD3(crossing.x / length, crossing.y / length, 0)
    }

    /// Follows the globe's round edge between two angles, the short way round.
    private func addEdgeArc(from: Double, to: Double, to path: inout Path) {
        var sweep = (to - from).truncatingRemainder(dividingBy: 2 * .pi)
        if sweep > .pi { sweep -= 2 * .pi }
        if sweep < -.pi { sweep += 2 * .pi }
        let steps = max(Int(abs(sweep) / 0.06), 1)
        for step in 1...steps {
            let angle = from + sweep * Double(step) / Double(steps)
            path.addLine(to: point(SIMD3(cos(angle), sin(angle), 0)))
        }
    }
}

/// The world's coastlines, read once from Data/land.json.
/// The outlines are Natural Earth's public-domain 1:110m land shapes.
enum LandShapes {
    static let rings: [[SIMD3<Double>]] = {
        guard let url = Bundle.main.url(forResource: "land", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([[[Double]]].self, from: data) else { return [] }

        return raw.map { ring in
            ring
                // The file runs Antarctica's edge down to the South Pole as a
                // straight line. Leaving those points out removes that line.
                .filter { $0.count == 2 && $0[1] > -89.9 }
                .map { GlobeProjection.unitVector(latitude: $0[1], longitude: $0[0]) }
        }
        .filter { $0.count >= 3 }
    }()
}
