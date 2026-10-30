import SwiftUI

/// Proportions of the top-down airplane, in units of wingspan.
enum AirplaneLayout {
    /// Spinner to tail.
    static let length: CGFloat = 0.52
    /// Spinner to the wing's leading edge.
    static let leadingEdge: CGFloat = 0.15
    static let chord: CGFloat = 0.14
    /// Centers of LT, LM, RM, RT across the span, nose up.
    static let tankX: [CGFloat] = [0.11, 0.33, 0.67, 0.89]
    /// Width of each tank's gauge column.
    static let columnWidth: CGFloat = 0.20
}

extension Color {
    /// The red trim of N8618W's paint.
    static let cherokeeRed = Color(red: 0.78, green: 0.11, blue: 0.13)
}

/// A path drawn in units of the frame's width.
private struct UnitShape: Shape {
    let build: @Sendable (inout Path, (CGFloat, CGFloat) -> CGPoint, CGFloat) -> Void

    func path(in rect: CGRect) -> Path {
        let s = rect.width
        var path = Path()
        build(&path, { CGPoint(x: rect.minX + $0 * s, y: rect.minY + $1 * s) }, s)
        return path
    }
}

/// A rounded rect in units of width; `leading`/`trailing` round only that side's corners.
private func unitRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                      radius r: CGFloat, leading: Bool = true, trailing: Bool = true) -> UnitShape {
    UnitShape { path, p, s in
        let l = leading ? r * s : 0, t = trailing ? r * s : 0
        path.addPath(Path(
            roundedRect: CGRect(origin: p(x, y), size: CGSize(width: w * s, height: h * s)),
            cornerRadii: RectangleCornerRadii(topLeading: l, bottomLeading: l, bottomTrailing: t, topTrailing: t)
        ))
    }
}

/// A Cherokee 235 seen from above, nose up: white with red wingtips,
/// stabilator tips and fin, drawn a little chubby.
struct AirplaneDrawing: View {
    private let paint = Color(.secondarySystemGroupedBackground)
    private let outline = Color.primary.opacity(0.28)
    private let glass = Color(red: 0.42, green: 0.55, blue: 0.68)

    var body: some View {
        let lead = AirplaneLayout.leadingEdge, chord = AirplaneLayout.chord
        let wing = unitRect(0, lead, 1, chord, radius: 0.035)
        let wingtips = UnitShape { path, p, s in
            let frame = CGRect(origin: p(0, 0), size: CGSize(width: s, height: s))
            path.addPath(unitRect(0, lead, 0.055, chord, radius: 0.035, trailing: false).path(in: frame))
            path.addPath(unitRect(0.945, lead, 0.055, chord, radius: 0.035, leading: false).path(in: frame))
        }
        let stabilator = unitRect(0.32, 0.42, 0.36, 0.065, radius: 0.025)
        let stabilatorTips = UnitShape { path, p, s in
            let frame = CGRect(origin: p(0, 0), size: CGSize(width: s, height: s))
            path.addPath(unitRect(0.32, 0.42, 0.04, 0.065, radius: 0.025, trailing: false).path(in: frame))
            path.addPath(unitRect(0.64, 0.42, 0.04, 0.065, radius: 0.025, leading: false).path(in: frame))
        }
        let fuselage = UnitShape { path, p, _ in
            path.move(to: p(0.465, 0.045))
            path.addQuadCurve(to: p(0.44, 0.12), control: p(0.44, 0.05))
            path.addLine(to: p(0.44, 0.31))
            path.addLine(to: p(0.482, 0.495))
            path.addQuadCurve(to: p(0.518, 0.495), control: p(0.5, 0.51))
            path.addLine(to: p(0.56, 0.31))
            path.addLine(to: p(0.56, 0.12))
            path.addQuadCurve(to: p(0.535, 0.045), control: p(0.56, 0.05))
            path.closeSubpath()
        }
        let canopy = unitRect(0.457, 0.14, 0.086, 0.105, radius: 0.03)
        let fin = unitRect(0.492, 0.385, 0.016, 0.125, radius: 0.008)
        let propeller = UnitShape { path, p, _ in
            path.move(to: p(0.42, 0.035))
            path.addLine(to: p(0.58, 0.035))
        }
        let spinner = UnitShape { path, p, s in
            path.addEllipse(in: CGRect(origin: p(0.475, 0.012), size: CGSize(width: 0.05 * s, height: 0.05 * s)))
        }

        ZStack {
            stabilator.fill(paint)
            stabilatorTips.fill(Color.cherokeeRed)
            stabilator.stroke(outline, lineWidth: 1)
            wing.fill(paint)
            wingtips.fill(Color.cherokeeRed)
            wing.stroke(outline, lineWidth: 1)
            fuselage.fill(paint)
            fuselage.stroke(outline, lineWidth: 1)
            canopy.fill(glass.opacity(0.55))
            canopy.stroke(outline, lineWidth: 1)
            fin.fill(Color.cherokeeRed)
            propeller.stroke(Color.primary.opacity(0.7), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            spinner.fill(paint)
            spinner.stroke(outline, lineWidth: 1)
        }
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
    private var labelsHeight: CGFloat { viewModel.isInFlight ? 64 : 116 }
    private let maxBarHeight: CGFloat = 200
    private let minBarHeight: CGFloat = 80

    var body: some View {
        GeometryReader { geo in
            let (span, gaugeHeight, height) = metrics(for: geo.size)
            let flying = viewModel.isInFlight

            ZStack(alignment: .topLeading) {
                AirplaneDrawing()
                    .frame(width: span, height: AirplaneLayout.length * span)
                    .offset(y: gaugeHeight - AirplaneLayout.leadingEdge * span)
                    .frame(width: span, height: height, alignment: .topLeading)
                    // Turning around the scene's center swaps the gauge side
                    // of the wing with the other side.
                    .rotationEffect(.degrees(flying ? 0 : 180))
                    .accessibilityHidden(true)

                ForEach(viewModel.tanks.indices, id: \.self) { index in
                    let x = flying ? AirplaneLayout.tankX[index] : 1 - AirplaneLayout.tankX[index]
                    let wingY = gaugeHeight + AirplaneLayout.chord / 2 * span

                    gauge(for: index, barScale: (gaugeHeight - labelsHeight) / maxCapacity)
                        .frame(width: AirplaneLayout.columnWidth * span, height: gaugeHeight,
                               alignment: flying ? .bottom : .top)
                        .position(x: x * span, y: flying ? gaugeHeight / 2 : height - gaugeHeight / 2)

                    wingLabel(for: index, span: span)
                        .position(x: x * span, y: flying ? wingY : height - wingY)
                }
            }
            .frame(width: span, height: height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Wingspan, gauge area height and total height for the space available.
    private func metrics(for size: CGSize) -> (span: CGFloat, gaugeHeight: CGFloat, height: CGFloat) {
        let below = AirplaneLayout.length - AirplaneLayout.leadingEdge
        // A little narrower than the screen, so the plane doesn't crowd it.
        var span = min(size.width * 0.92, 480)
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

    /// The tank's name on the wing where it sits. In flight it's another way to switch tanks.
    @ViewBuilder
    private func wingLabel(for index: Int, span: CGFloat) -> some View {
        let tank = viewModel.tanks[index]
        let feeding = viewModel.isInFlight && viewModel.lastActiveTankIndex == index
        let label = Text(tank.name)
            .font(.caption.weight(.bold))
            .foregroundStyle(feeding ? Color.white : Color.primary)
            .frame(width: 0.12 * span, height: 0.62 * AirplaneLayout.chord * span)
            .background(feeding ? Color.accentColor : Color(.systemBackground), in: Capsule())
            .overlay(Capsule().stroke(feeding ? Color.accentColor : Color(.systemGray3), lineWidth: 1))

        if viewModel.isInFlight {
            Button { onTapTank(index) } label: {
                label
                    .frame(width: AirplaneLayout.columnWidth * span, height: AirplaneLayout.chord * span)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5).onEnded { _ in onLongPressTank(index) }
            )
            .accessibilityLabel(feeding ? "\(tank.name), feeding" : tank.name)
            .accessibilityHint("Switches to this tank")
        } else {
            label.accessibilityHidden(true)
        }
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
