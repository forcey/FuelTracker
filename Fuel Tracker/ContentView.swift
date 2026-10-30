import SwiftUI

/// The tank a switch sheet is open for.
private struct SwitchTarget: Identifiable {
    let id: Int
}

struct ContentView: View {
    @StateObject private var viewModel = FuelViewModel()
    @State private var switchTarget: SwitchTarget? = nil
    @State private var showEditSheet = false

    private var isLow: Bool { viewModel.enduranceHours < 1 }

    @ViewBuilder
    private func tankButton(for index: Int) -> some View {
        let tank = viewModel.tanks[index]
        let percent = max(min(tank.gallons / tank.capacity, 1), 0)
        let isFeeding = viewModel.lastActiveTankIndex == index
        let color: Color = viewModel.editingTankIndex == index ? .red :
            isFeeding ? .accentColor : Color(.systemGray)

        VStack(spacing: 8) {
            Button {
                if viewModel.editingTankIndex != index {
                    switchTarget = SwitchTarget(id: index)
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 6)

                    Circle()
                        .trim(from: 0, to: percent)
                        .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    Text(String(format: "%.0f", tank.gallons))
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(8)
                }
                // Shrink to fit narrow screens (e.g. the outside display), up to 66pt.
                .frame(maxWidth: 66)
                .aspectRatio(1, contentMode: .fit)
                .padding(3)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        viewModel.startEditingTank(index: index)
                        showEditSheet = true
                    }
            )

            VStack(spacing: 2) {
                Text(tank.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isFeeding ? Color.accentColor : .primary)
                if isFeeding {
                    Image(systemName: "triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityLabel("Feeding")
                } else {
                    Text("of \(String(format: "%.0f", tank.capacity))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

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

    private func statCard(_ title: String, gallons: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%.1f", gallons))
                    .font(.title.weight(.medium))
                    .monospacedDigit()
                Text("gal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("CHEROKEE 235")
                    .font(.footnote.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(.secondary)
                Spacer()
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

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("Endurance")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    timerIndicator
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(viewModel.enduranceText)
                        .font(.system(size: 88, weight: .thin))
                        .monospacedDigit()
                        .foregroundStyle(isLow ? .red : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("h")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                Text("\(viewModel.enduranceMinusReserveText) after 45 min reserve")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(isLow ? .red : .secondary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                    .padding(.top, 6)
            }

            HStack(alignment: .top, spacing: 4) {
                ForEach(viewModel.tanks.indices, id: \.self) { index in
                    if index == viewModel.tanks.count / 2 {
                        // Fuselage between the left and right wing tanks.
                        Capsule()
                            .fill(Color(.systemGray5))
                            .frame(width: 2, height: 56)
                            .padding(.horizontal, 4)
                            .padding(.top, 8)
                    }
                    tankButton(for: index)
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 10)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28))

            HStack(spacing: 12) {
                statCard("Remaining", gallons: viewModel.totalRemainingGallons())
                statCard("Used", gallons: viewModel.totalUsedGallons ?? 0)
            }

            if !viewModel.lastSwitchText.isEmpty {
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

            Spacer(minLength: 0)

            Text("Tap a tank to switch · Hold to set its level")
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
