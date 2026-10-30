import SwiftUI

/// Type a tank's level in gallons or as a FuelHawk reading.
struct LevelEntrySheet: View {
    let tank: Tank
    @EnvironmentObject var viewModel: FuelViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var unit: LevelUnit
    @State private var input = ""
    @FocusState private var isInputFocused: Bool

    init(tank: Tank, unit: LevelUnit) {
        self.tank = tank
        self._unit = State(initialValue: unit)
    }

    private var range: ClosedRange<Double> {
        unit == .gallons ? 0...tank.capacity : 0...tank.maxFuelHawkReading
    }

    private func gallons(from value: Double, in unit: LevelUnit) -> Double {
        unit == .gallons ? value : tank.convertFuelHawk(value)
    }

    private func value(fromGallons gallons: Double, in unit: LevelUnit) -> Double {
        unit == .gallons ? gallons : tank.fuelHawkReading(forGallons: gallons)
    }

    /// The typed level in gallons, if it's a number in range.
    private var enteredGallons: Double? {
        guard let value = Double(input), range.contains(value) else { return nil }
        return gallons(from: value, in: unit)
    }

    private var unitLabel: String { unit == .gallons ? "gal" : "FH" }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(String(format: "%.0f", tank.capacity)) gal tank")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Set \(tank.name) level")
                    .font(.title.weight(.semibold))
            }

            Picker("Unit", selection: $unit) {
                ForEach(LevelUnit.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TextField(String(format: "%.1f", value(fromGallons: tank.gallons, in: unit)), text: $input)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 40, weight: .light))
                    .monospacedDigit()
                    .focused($isInputFocused)
                Text(unitLabel)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 18)
            .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.accentColor, lineWidth: 2))

            Group {
                if let gallons = enteredGallons {
                    Text(unit == .gallons
                         ? "FuelHawk \(String(format: "%.1f", tank.fuelHawkReading(forGallons: gallons)))"
                         : "\(String(format: "%.1f", gallons)) gal")
                } else if input.isEmpty {
                    Text("Now \(String(format: "%.1f", tank.gallons)) gal")
                } else {
                    Text("Enter 0 to \(String(format: unit == .gallons ? "%.0f" : "%.1f", range.upperBound)) \(unitLabel)")
                        .foregroundStyle(.red)
                }
            }
            .font(.subheadline)
            .monospacedDigit()
            .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    if let gallons = enteredGallons {
                        tank.gallons = gallons
                        viewModel.saveState()
                    }
                    dismiss()
                } label: {
                    Text("Set Level").fontWeight(.semibold).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(enteredGallons == nil)
            }
            .controlSize(.large)
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(.secondarySystemGroupedBackground))
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onChange(of: unit) { oldUnit, newUnit in
            // Keep what was typed, converted to the new unit.
            if let typed = Double(input) {
                let typedGallons = gallons(from: typed, in: oldUnit)
                input = String(format: "%.1f", value(fromGallons: typedGallons, in: newUnit))
            }
        }
        .onAppear { isInputFocused = true }
    }
}
