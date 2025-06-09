import SwiftUI

struct TankEditor: View {
    let tank: Tank
    @Binding var showEditSheet: Bool
    @EnvironmentObject var viewModel: FuelViewModel
    @State private var hasMovedSlider: Bool
    @State private var sliderReading: Double

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

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                ForEach(tickerRange, id: \.self) { reading in
                    let gallons = tank.convertFuelHawk(reading)
                    Text(String(format: "%.0f", gallons))
                        .frame(maxWidth: .infinity)
                        .font(.caption2)
                }
                Text("gal").font(.caption2).frame(width: 30)
            }

            Slider(value: $sliderReading, in: 0...tank.maxFuelHawkReading, step: 0.1)
                .onChange(of: sliderReading, initial: false) { _, _ in
                    hasMovedSlider = true
                }

            HStack {
                ForEach(tickerRange, id: \.self) { reading in
                    Text(String(format: "%.0f", reading))
                        .frame(maxWidth: .infinity)
                        .font(.caption2)
                }
                Text("Fuel\nHawk").font(.caption2).frame(width: 30)
            }

            Text(String(format: "%.1f FuelHawk / %.1f gallons", sliderReading, tank.convertFuelHawk(sliderReading)))

            HStack(spacing: 10) {
                Button("Empty") {
                    tank.gallons = 0
                    hasMovedSlider = false
                    showEditSheet = false
                    viewModel.saveState()
                }
                Button("Full") {
                    tank.gallons = tank.capacity
                    hasMovedSlider = false
                    showEditSheet = false
                    viewModel.saveState()
                }
                Button("All Tanks Full") {
                    viewModel.fillAllTanks()
                    hasMovedSlider = false
                    showEditSheet = false
                }
            }
            .buttonStyle(.bordered)

            HStack(spacing: 20) {
                Button("Cancel") {
                    showEditSheet = false
                }
                .buttonStyle(.bordered)

                Button("Reset Amount") {
                    tank.gallons = tank.convertFuelHawk(sliderReading)
                    hasMovedSlider = false
                    showEditSheet = false
                    viewModel.saveState()
                }
                .disabled(!hasMovedSlider)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal)
        .presentationDetents([.medium])

    }
}
