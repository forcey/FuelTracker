import SwiftUI

/// Proportions of the top-down airplane, in units of wingspan.
enum AirplaneLayout {
    /// Nose to tail.
    static let length: CGFloat = 0.75
    /// Nose to the wing's leading edge.
    static let leadingEdge: CGFloat = 0.20
    static let chord: CGFloat = 0.15
    /// Centers of LT, LM, RM, RT across the span, nose up.
    static let tankX: [CGFloat] = [0.10, 0.33, 0.67, 0.90]
    /// Width of each tank's gauge column.
    static let columnWidth: CGFloat = 0.20
}

/// Wireframe of a low-wing single seen from above, nose up, like an FMS map symbol.
struct AirplaneShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }
        var path = Path()

        // Wing
        path.addRoundedRect(
            in: CGRect(origin: p(0.02, AirplaneLayout.leadingEdge),
                       size: CGSize(width: 0.96 * s, height: AirplaneLayout.chord * s)),
            cornerSize: CGSize(width: 0.04 * s, height: 0.04 * s)
        )
        // Horizontal stabilizer
        path.addRoundedRect(
            in: CGRect(origin: p(0.36, 0.63), size: CGSize(width: 0.28 * s, height: 0.07 * s)),
            cornerSize: CGSize(width: 0.02 * s, height: 0.02 * s)
        )
        // Fuselage
        path.move(to: p(0.5, 0.035))
        path.addQuadCurve(to: p(0.54, 0.13), control: p(0.54, 0.04))
        path.addLine(to: p(0.54, 0.38))
        path.addLine(to: p(0.515, 0.73))
        path.addLine(to: p(0.485, 0.73))
        path.addLine(to: p(0.46, 0.38))
        path.addLine(to: p(0.46, 0.13))
        path.addQuadCurve(to: p(0.5, 0.035), control: p(0.46, 0.04))
        path.closeSubpath()
        // Propeller
        path.move(to: p(0.44, 0.02))
        path.addLine(to: p(0.56, 0.02))
        path.move(to: p(0.5, 0.02))
        path.addLine(to: p(0.5, 0.035))

        return path
    }
}

/// The airplane with a fuel gauge over each tank. In flight it points nose up,
/// as seen from the cockpit; in preflight it turns around to face you, as seen
/// standing in front of it, so the left wing is on your right.
struct AirplaneScene: View {
    @ObservedObject var viewModel: FuelViewModel
    let onTapTank: (Int) -> Void
    let onLongPressTank: (Int) -> Void
    let onEnterLevel: (Int, LevelUnit) -> Void

    /// Room the gauge's labels take up besides the bar.
    private var labelsHeight: CGFloat { viewModel.isInFlight ? 76 : 132 }
    private let maxBarHeight: CGFloat = 200
    private let minBarHeight: CGFloat = 80

    var body: some View {
        GeometryReader { geo in
            let (span, gaugeHeight, height) = metrics(for: geo.size)

            ZStack(alignment: .topLeading) {
                planeLayer(span: span, gaugeHeight: gaugeHeight)
                    .frame(width: span, height: height)
                    // Turning around the scene's center swaps the gauge side
                    // of the wing with the other side.
                    .rotationEffect(.degrees(viewModel.isInFlight ? 0 : 180))

                ForEach(viewModel.tanks.indices, id: \.self) { index in
                    let x = AirplaneLayout.tankX[index]
                    gauge(for: index, barScale: (gaugeHeight - labelsHeight) / maxCapacity)
                        .frame(width: AirplaneLayout.columnWidth * span, height: gaugeHeight,
                               alignment: viewModel.isInFlight ? .bottom : .top)
                        .position(
                            x: (viewModel.isInFlight ? x : 1 - x) * span,
                            y: viewModel.isInFlight ? gaugeHeight / 2 : height - gaugeHeight / 2
                        )
                }
            }
            .frame(width: span, height: height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Wingspan, gauge area height and total height for the space available.
    private func metrics(for size: CGSize) -> (span: CGFloat, gaugeHeight: CGFloat, height: CGFloat) {
        let below = AirplaneLayout.length - AirplaneLayout.leadingEdge
        var span = min(size.width, 520)
        // Gauge area: whatever fits beside a full-width plane, within limits.
        let gaugeHeight = min(max(size.height - below * span, labelsHeight + minBarHeight),
                              labelsHeight + maxBarHeight)
        // On short screens, shrink the plane rather than the gauges.
        span = min(span, max((size.height - gaugeHeight) / below, 200))
        return (span, gaugeHeight, gaugeHeight + below * span)
    }

    private var maxCapacity: CGFloat {
        viewModel.tanks.map { CGFloat($0.capacity) }.max() ?? 1
    }

    /// The plane, nose up, with its wing's leading edge at the bottom of the gauge area.
    private func planeLayer(span: CGFloat, gaugeHeight: CGFloat) -> some View {
        let planeTop = gaugeHeight - AirplaneLayout.leadingEdge * span
        return ZStack(alignment: .topLeading) {
            AirplaneShape()
                .stroke(Color.secondary, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                .frame(width: span, height: AirplaneLayout.length * span)
                .offset(y: planeTop)

            // Where each tank sits in the wing.
            ForEach(viewModel.tanks.indices, id: \.self) { index in
                let feeding = viewModel.isInFlight && viewModel.lastActiveTankIndex == index
                Capsule()
                    .fill(feeding ? Color.accentColor.opacity(0.35) : Color.clear)
                    .overlay(Capsule().stroke(feeding ? Color.accentColor : Color(.systemGray3), lineWidth: 1))
                    .frame(width: 0.09 * span, height: 0.07 * span)
                    .position(x: AirplaneLayout.tankX[index] * span,
                              y: planeTop + (AirplaneLayout.leadingEdge + AirplaneLayout.chord / 2) * span)
            }
        }
        .accessibilityHidden(true)
    }

    private func gauge(for index: Int, barScale: CGFloat) -> some View {
        let tank = viewModel.tanks[index]
        return FuelGauge(
            tank: tank,
            isInFlight: viewModel.isInFlight,
            isFeeding: viewModel.lastActiveTankIndex == index,
            isEditing: viewModel.editingTankIndex == index,
            barHeight: CGFloat(tank.capacity) * barScale,
            tallestBarHeight: maxCapacity * barScale,
            onTap: { onTapTank(index) },
            onLongPress: { onLongPressTank(index) },
            onEnter: { onEnterLevel(index, $0) },
            onScrubEnded: { viewModel.saveState() }
        )
    }
}
