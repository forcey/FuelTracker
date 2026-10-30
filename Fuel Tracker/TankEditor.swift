import SwiftUI

struct TankEditor: View {
    let tank: Tank
    @Binding var showEditSheet: Bool
    @EnvironmentObject var viewModel: FuelViewModel
    @State private var hasMovedSlider: Bool
    @State private var sliderReading: Double
    @State private var contentHeight: CGFloat = 0

    init(tank: Tank, showEditSheet: Binding<Bool>) {
        self.tank = tank
        self._showEditSheet = showEditSheet
        self._hasMovedSlider = State(initialValue: false)
        self._sliderReading = State(initialValue: tank.maxFuelHawkReading / 2)
    }

    private var tickerRange: [Double] {
        Array(
            stride(
                from: 0.0,
                through: tank.maxFuelHawkReading,
                by: tank.maxFuelHawkReading / 4
            )
        )
    }

    private func setGallons(_ gallons: Double) {
        tank.gallons = gallons
        hasMovedSlider = false
        showEditSheet = false
        viewModel.saveState()
    }

    var body: some View {
        // Size the sheet to its content so short screens (e.g. the outside
        // display) don't clip it; scroll if it's taller than the screen.
        ScrollView {
            content
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                    contentHeight = $0
                }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color(.secondarySystemGroupedBackground))
        .presentationDetents(contentHeight > 0 ? [.height(contentHeight)] : [.medium])
        .presentationDragIndicator(.visible)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(String(format: "%.0f", tank.capacity)) gal tank")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Set \(tank.name) level")
                    .font(.title.weight(.semibold))
            }

            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%.1f", tank.convertFuelHawk(sliderReading)))
                    .font(.system(size: 52, weight: .light))
                    .monospacedDigit()
                Text("gal")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("FuelHawk \(String(format: "%.1f", sliderReading))")
                    .font(.subheadline)
                    .monospacedDigit()
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
            }

            VStack(spacing: 8) {
                HStack {
                    ForEach(tickerRange, id: \.self) { reading in
                        Text(String(format: "%.0f", tank.convertFuelHawk(reading)))
                            .frame(maxWidth: .infinity)
                    }
                    Text("gal").frame(width: 35)
                }

                Slider(value: $sliderReading, in: 0...tank.maxFuelHawkReading, step: 0.1)
                    .onChange(of: sliderReading, initial: false) { _, _ in
                        hasMovedSlider = true
                    }
                    .padding(.trailing, 43)

                HStack {
                    ForEach(tickerRange, id: \.self) { reading in
                        Text(String(format: "%.1f", reading))
                            .frame(maxWidth: .infinity)
                    }
                    Text("FH").frame(width: 35)
                }
            }
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    showEditSheet = false
                } label: {
                    Text("Cancel").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    setGallons(tank.convertFuelHawk(sliderReading))
                } label: {
                    Text("Set Level").fontWeight(.semibold).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasMovedSlider)
            }
            .controlSize(.large)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Quick set")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Button {
                        setGallons(0)
                    } label: {
                        Text("Empty").frame(maxWidth: .infinity)
                    }
                    .foregroundStyle(.red)

                    Button {
                        setGallons(tank.capacity)
                    } label: {
                        Text("Full").frame(maxWidth: .infinity)
                    }

                    Button {
                        viewModel.fillAllTanks()
                        hasMovedSlider = false
                        showEditSheet = false
                    } label: {
                        Text("All Full").frame(maxWidth: .infinity)
                    }
                    .accessibilityLabel("All Tanks Full")
                }
                .buttonStyle(.bordered)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
        }
        .padding(20)
        .padding(.top, 8)
    }
}
