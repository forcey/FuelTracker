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

    private var isLow: Bool { viewModel.enduranceHours < 1 }
    private var totalCapacity: Double { viewModel.tanks.reduce(0) { $0 + $1.capacity } }

    /// Width of the status-bar column on the side of the screen (iPhone Duo), if there is one.
    private func sidebarWidth(_ insets: EdgeInsets) -> CGFloat? {
        insets.trailing >= 60 ? insets.trailing : nil
    }

    private func statCell(
        _ title: String, value: String, unit: String? = nil, warn: Bool = false, ticking: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                ClockText(text: value, isTicking: ticking)
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
                statCell("Endurance", value: viewModel.enduranceText, warn: isLow,
                         ticking: viewModel.isTimerRunning)
                statCell("After 45 min reserve", value: viewModel.enduranceMinusReserveText, warn: isLow,
                         ticking: viewModel.isTimerRunning)
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

    private func toggleMode() {
        withAnimation(.spring(duration: 0.7)) { viewModel.setInFlight(!viewModel.isInFlight) }
    }

    private var modeName: String { viewModel.isInFlight ? "In Flight" : "Preflight" }

    private var modeButton: some View {
        Button(action: toggleMode) {
            Label(modeName, systemImage: "arrow.triangle.2.circlepath")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(Color(.secondarySystemGroupedBackground), in: Capsule())
        }
        .accessibilityHint(viewModel.isInFlight ? "Switches to preflight" : "Switches to in flight and starts the timer")
    }

    private var moreMenu: some View {
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

    private var title: some View {
        Text("CHEROKEE 235")
            .font(.footnote.weight(.semibold))
            .tracking(1)
            .foregroundStyle(.secondary)
    }

    /// The title and buttons stacked in the status-bar column, within thumb reach.
    private var sidebarHeader: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("CHEROKEE\n235")
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize()
            Button(action: toggleMode) {
                VStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title3.weight(.semibold))
                        .frame(width: 52, height: 52)
                        .background(Color(.secondarySystemGroupedBackground), in: Circle())
                    Text(modeName)
                        .font(.caption.weight(.semibold))
                }
            }
            .accessibilityLabel(modeName)
            .accessibilityHint(viewModel.isInFlight ? "Switches to preflight" : "Switches to in flight and starts the timer")
            moreMenu
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 16)
    }

    var body: some View {
        GeometryReader { geo in
            let sidebar = sidebarWidth(geo.safeAreaInsets)
            HStack(spacing: 0) {
                mainColumn(showsHeader: sidebar == nil)
                if let sidebar {
                    sidebarHeader.frame(width: sidebar)
                }
            }
            .ignoresSafeArea(.container, edges: sidebar == nil ? [] : .trailing)
        }
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

    private func mainColumn(showsHeader: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if showsHeader {
                HStack(spacing: 10) {
                    title
                    Spacer()
                    modeButton
                    moreMenu
                }
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
    }
}

/// "4:45", with the colon blinking every second while the clock runs.
private struct ClockText: View {
    let text: String
    let isTicking: Bool

    var body: some View {
        if isTicking, let colon = text.firstIndex(of: ":") {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let shown = Int(context.date.timeIntervalSinceReferenceDate) % 2 == 0
                Text("""
                    \(Text(text[..<colon]))\
                    \(Text(":").foregroundStyle(shown ? AnyShapeStyle(.foreground) : AnyShapeStyle(.clear)))\
                    \(Text(text[text.index(after: colon)...]))
                    """)
            }
        } else {
            Text(text)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
