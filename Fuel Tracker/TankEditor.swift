import SwiftUI

struct TankEditor: View {
    private enum Field { case gallons, fuelHawk }

    let tank: Tank
    @Binding var showEditSheet: Bool
    @EnvironmentObject var viewModel: FuelViewModel
    /// The level to set, in gallons.
    @State private var gallons: Double
    @State private var gallonsText: String
    @State private var fuelHawkText: String
    @State private var hasChanged = false
    @State private var isInputValid = true
    @FocusState private var focusedField: Field?
    @State private var contentHeight: CGFloat = 0

    init(tank: Tank, showEditSheet: Binding<Bool>) {
        self.tank = tank
        self._showEditSheet = showEditSheet
        self._gallons = State(initialValue: tank.gallons)
        self._gallonsText = State(initialValue: String(format: "%.1f", tank.gallons))
        self._fuelHawkText = State(initialValue: String(format: "%.1f", tank.fuelHawkReading(forGallons: tank.gallons)))
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

    private var sliderReading: Binding<Double> {
        Binding {
            tank.fuelHawkReading(forGallons: gallons)
        } set: { reading in
            focusedField = nil
            gallons = tank.convertFuelHawk(reading)
            gallonsText = String(format: "%.1f", gallons)
            fuelHawkText = String(format: "%.1f", reading)
            isInputValid = true
            hasChanged = true
        }
    }

    /// Parses a typed number, sets `gallons` from it if it's in range, and
    /// returns the new level so the other field can show it.
    private func applyTyped(_ text: String, range: ClosedRange<Double>, toGallons: (Double) -> Double) -> Double? {
        hasChanged = true
        guard let value = Double(text), range.contains(value) else {
            isInputValid = false
            return nil
        }
        isInputValid = true
        gallons = toGallons(value)
        return gallons
    }

    private func setGallons(_ gallons: Double) {
        tank.gallons = gallons
        hasChanged = false
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
                TextField("0", text: $gallonsText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .gallons)
                    .font(.system(size: 52, weight: .light))
                    .monospacedDigit()
                    .fixedSize()
                    .accessibilityLabel("Gallons")
                    .onChange(of: gallonsText) { _, text in
                        guard focusedField == .gallons else { return }
                        if let gallons = applyTyped(text, range: 0...tank.capacity, toGallons: { $0 }) {
                            fuelHawkText = String(format: "%.1f", tank.fuelHawkReading(forGallons: gallons))
                        }
                    }
                Text("gal")
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Text("FuelHawk")
                    TextField("0", text: $fuelHawkText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .fuelHawk)
                        .monospacedDigit()
                        .fixedSize()
                        .accessibilityLabel("FuelHawk reading")
                        .onChange(of: fuelHawkText) { _, text in
                            guard focusedField == .fuelHawk else { return }
                            if let gallons = applyTyped(text, range: 0...tank.maxFuelHawkReading, toGallons: tank.convertFuelHawk) {
                                gallonsText = String(format: "%.1f", gallons)
                            }
                        }
                }
                .font(.subheadline)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
                .onTapGesture { focusedField = .fuelHawk }
            }
            .foregroundStyle(isInputValid ? Color.primary : Color.red)

            VStack(spacing: 8) {
                HStack {
                    ForEach(tickerRange, id: \.self) { reading in
                        Text(String(format: "%.0f", tank.convertFuelHawk(reading)))
                            .frame(maxWidth: .infinity)
                    }
                    Text("gal").frame(width: 35)
                }

                Slider(value: sliderReading, in: 0...tank.maxFuelHawkReading, step: 0.1)
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
                    setGallons(gallons)
                } label: {
                    Text("Set Level").fontWeight(.semibold).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasChanged || !isInputValid)
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
                        hasChanged = false
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
