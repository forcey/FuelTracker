import SwiftUI

/// The tank a switch sheet is open for.
private struct SwitchTarget: Identifiable {
    let id: Int
}

/// The tank and unit a level-entry sheet is open for.
private struct LevelEntry: Identifiable {
    let tankIndex: Int
    let unit: LevelUnit
    var id: String { "\(tankIndex)-\(unit.rawValue)" }
}

struct ContentView: View {
    @StateObject private var viewModel = FuelViewModel()
    @State private var switchTarget: SwitchTarget? = nil
    @State private var levelEntry: LevelEntry? = nil
    @State private var showEditSheet = false
    @State private var confirmPreflight = false

    private var isLow: Bool { viewModel.enduranceHours < 1 }
    private var totalCapacity: Double { viewModel.tanks.reduce(0) { $0 + $1.capacity } }

    private var timerIndicator: some View {
        let running = viewModel.isTimerRunning
        return HStack(spacing: 4) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundStyle(running ? Color.green : Color(.systemGray3))
                .symbolEffect(.pulse, options: .repeating, isActive: running)
            Text(running ? "Running" : "Stopped")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(running ? "Timer running" : "Timer stopped")
    }

    private func statCell<Accessory: View>(
        _ title: String, value: String, unit: String? = nil, warn: Bool = false,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                accessory()
            }
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value)
                    .font(.title2.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(warn ? .red : .primary)
                if let unit {
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground))
    }

    @ViewBuilder
    private var stats: some View {
        let columns = [GridItem(.flexible(), spacing: 1), GridItem(.flexible(), spacing: 1)]
        LazyVGrid(columns: columns, spacing: 1) {
            if viewModel.isInFlight {
                statCell("Endurance", value: viewModel.enduranceText, warn: isLow) { timerIndicator }
                statCell("After 45 min reserve", value: viewModel.enduranceMinusReserveText, warn: isLow)
                statCell("Remaining", value: String(format: "%.1f", viewModel.totalRemainingGallons()), unit: "gal")
                statCell("Used", value: String(format: "%.1f", viewModel.totalUsedGallons ?? 0), unit: "gal")
            } else {
                statCell("Fuel on board", value: String(format: "%.1f", viewModel.totalRemainingGallons()),
                         unit: "of \(String(format: "%.0f", totalCapacity)) gal")
                statCell("Endurance", value: viewModel.enduranceText, unit: "h")
            }
        }
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var modeButton: some View {
        Button {
            if viewModel.isInFlight {
                confirmPreflight = true
            } else {
                withAnimation(.spring(duration: 0.7)) { viewModel.setInFlight(true) }
            }
        } label: {
            Label(viewModel.isInFlight ? "In Flight" : "Preflight", systemImage: "arrow.triangle.2.circlepath")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(Color(.secondarySystemGroupedBackground), in: Capsule())
        }
        .accessibilityHint(viewModel.isInFlight ? "Switches to preflight" : "Switches to in flight and starts the timer")
        .confirmationDialog("Switch to preflight?", isPresented: $confirmPreflight, titleVisibility: .visible) {
            Button("Switch to Preflight") {
                withAnimation(.spring(duration: 0.7)) { viewModel.setInFlight(false) }
            }
        } message: {
            Text("The endurance timer stops. It starts again from now when you switch back to in flight.")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Text("CHEROKEE 235")
                    .font(.footnote.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(.secondary)
                Spacer()
                modeButton
                Menu {
                    Button("Reset Used", systemImage: "arrow.counterclockwise") {
                        viewModel.totalUsedGallons = nil
                        viewModel.saveState()
                    }
                    Button("All Tanks Full", systemImage: "fuelpump") {
                        viewModel.fillAllTanks()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(Color(.secondarySystemGroupedBackground), in: Circle())
                }
                .accessibilityLabel("More")
            }

            stats

            AirplaneScene(
                viewModel: viewModel,
                onTapTank: { index in
                    if viewModel.editingTankIndex != index {
                        switchTarget = SwitchTarget(id: index)
                    }
                },
                onLongPressTank: { index in
                    viewModel.startEditingTank(index: index)
                    showEditSheet = true
                },
                onEnterLevel: { index, unit in
                    levelEntry = LevelEntry(tankIndex: index, unit: unit)
                }
            )
            .frame(maxHeight: .infinity)

            if viewModel.isInFlight && !viewModel.lastSwitchText.isEmpty {
                HStack(spacing: 14) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Color(.secondarySystemGroupedBackground), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.lastSwitchText)
                            .font(.subheadline.weight(.medium))
                        Text("at \(String(format: "%.1f", viewModel.totalUsedGallons ?? 0)) gal used")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 6)
            }

            Text(viewModel.isInFlight
                 ? "Tap a tank to switch · Hold to set its level"
                 : "Drag a gauge to set its level · Tap a number to type it")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showEditSheet) {
            TankEditor(
                tank: viewModel.tanks[viewModel.editingTankIndex!],
                showEditSheet: $showEditSheet
            )
            .environmentObject(viewModel)
            .onDisappear {
                viewModel.stopEditingTank()
            }
        }
        .sheet(item: $switchTarget) { target in
            SwitchTankSheet(toIndex: target.id)
                .environmentObject(viewModel)
        }
        .sheet(item: $levelEntry) { entry in
            LevelEntrySheet(tank: viewModel.tanks[entry.tankIndex], unit: entry.unit)
                .environmentObject(viewModel)
        }
        .onAppear {
            if viewModel.lastActiveTankIndex == nil {
                viewModel.lastActiveTankIndex = 0
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
