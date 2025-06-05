import SwiftUI

struct TankEditor: View {
    let tank: Tank
    @Binding var editingTankIndex: Int?
    @State private var hasMovedSlider: Bool
    @State private var sliderReading: Double

    init(tank: Tank, editingTankIndex: Binding<Int?>) {
        self.tank = tank
        self._editingTankIndex = editingTankIndex
        self._hasMovedSlider = State(initialValue: false)
        self._sliderReading = State(initialValue: tank.maxFuelHawkReading / 2)
    }

    var body: some View {
        let tickerRange = Array(stride(from: 0.0, through: tank.maxFuelHawkReading, by: tank.maxFuelHawkReading / 4))

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

            Slider(value: $sliderReading, in: 0...tank.maxFuelHawkReading, step: 0.1, onEditingChanged: { editing in
                if editing {
                    self.hasMovedSlider = true
                }
            })

            HStack {
                ForEach(tickerRange, id: \.self) { reading in
                    Text(String(format: "%.0f", reading))
                        .frame(maxWidth: .infinity)
                        .font(.caption2)
                }
                Text("Fuel\nHawk").font(.caption2).frame(width: 30)
            }

            Text(String(format: "%.1f FuelHawk / %.1f gallons", sliderReading, tank.convertFuelHawk(sliderReading)))

            Button(action: {
                let newGallons = tank.convertFuelHawk(sliderReading)
                tank.gallons = newGallons
                self.hasMovedSlider = false
                editingTankIndex = nil
            }) {
                Text("Reset Amount")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(self.hasMovedSlider ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(!self.hasMovedSlider || editingTankIndex == nil)
        }
        .padding(.horizontal)
    }
}
