import SwiftUI

enum LevelUnit: String, CaseIterable, Identifiable {
    case gallons = "Gallons"
    case fuelHawk = "FuelHawk"

    var id: Self { self }
}

/// One tank's vertical gauge; its name is on the wing below it. In flight: tap
/// to switch to it, hold to set its level. In preflight: drag the bar to set the
/// level, or tap a number to type it.
struct FuelGauge: View {
    @ObservedObject var tank: Tank
    let isInFlight: Bool
    let isFeeding: Bool
    let isEditing: Bool
    /// Height of a full tank's bar.
    let barHeight: CGFloat
    /// Height of the largest tank's bar, so preflight readings line up across gauges.
    let tallestBarHeight: CGFloat
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onEnter: (LevelUnit) -> Void
    let onScrubEnded: () -> Void

    @State private var isScrubbing = false

    private var fraction: CGFloat {
        CGFloat(max(min(tank.gallons / tank.capacity, 1), 0))
    }

    private var barColor: Color {
        if isEditing { return .red }
        if !isInFlight || isFeeding { return .accentColor }
        return Color(.systemGray)
    }

    var body: some View {
        VStack(spacing: 6) {
            if isInFlight {
                Text(String(format: "%.1f", tank.gallons))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                flightBar
                // Always takes up room, so the bars stay level when the feeding tank changes.
                Image(systemName: "triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor)
                    .opacity(isFeeding ? 1 : 0)
                    .accessibilityHidden(true)
            } else {
                scrubBar
                    .frame(height: tallestBarHeight, alignment: .top)
                    .padding(.top, 4)
                VStack(spacing: 6) {
                    valueButton(String(format: "%.1f", tank.gallons), unit: "gal", for: .gallons)
                    valueButton(String(format: "%.1f", tank.fuelHawkReading(forGallons: tank.gallons)),
                                unit: "FuelHawk", for: .fuelHawk)
                }
            }
        }
    }

    private var bar: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray5))
            Rectangle()
                .fill(barColor)
                .frame(height: barHeight * fraction)
            // A tick every 5 gallons, like a gauge's scale.
            ForEach(1..<Int(tank.capacity / 5) + 1, id: \.self) { step in
                let y = barHeight * CGFloat(Double(step * 5) / tank.capacity)
                if y < barHeight - 4 {
                    Rectangle()
                        .fill(Color(.systemBackground).opacity(0.6))
                        .frame(height: 1)
                        .padding(.horizontal, 8)
                        .offset(y: -y)
                }
            }
        }
        .frame(height: barHeight)
        .frame(maxWidth: 52)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var flightBar: some View {
        Button(action: onTap) { bar }
            .buttonStyle(.plain)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5).onEnded { _ in onLongPress() }
            )
            .accessibilityLabel("\(tank.name), \(String(format: "%.1f", tank.gallons)) gallons")
            .accessibilityHint("Switches to this tank")
    }

    private var scrubBar: some View {
        bar
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isScrubbing = true
                        setFraction(1 - value.location.y / barHeight)
                    }
                    .onEnded { _ in
                        isScrubbing = false
                        onScrubEnded()
                    }
            )
            .sensoryFeedback(.selection, trigger: tank.gallons) { _, _ in isScrubbing }
            .accessibilityElement()
            .accessibilityLabel(tank.name)
            .accessibilityValue("\(String(format: "%.1f", tank.gallons)) gallons")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: tank.gallons = min(tank.gallons + 1, tank.capacity)
                case .decrement: tank.gallons = max(tank.gallons - 1, 0)
                @unknown default: break
                }
                onScrubEnded()
            }
    }

    /// Sets the level from a point on the bar, in half-gallon steps.
    private func setFraction(_ fraction: CGFloat) {
        let clamped = Double(max(min(fraction, 1), 0))
        let gallons = (clamped * tank.capacity * 2).rounded() / 2
        if gallons != tank.gallons {
            tank.gallons = gallons
        }
    }

    private func valueButton(_ value: String, unit: String, for levelUnit: LevelUnit) -> some View {
        Button {
            onEnter(levelUnit)
        } label: {
            VStack(spacing: 0) {
                Text(value)
                    .font(.headline)
                    .monospacedDigit()
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(tank.name), \(value) \(unit)")
        .accessibilityHint("Type a new reading")
    }
}
