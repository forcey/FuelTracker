import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = FuelViewModel()
    @State private var selectedTankIndex: Int? = nil
    @State private var usedInput: String = "5"
    @State private var showEditSheet = false
    @State private var showSwitchSheet = false
    @FocusState private var isInputFocused: Bool

    @ViewBuilder
    private func tankButton(for index: Int) -> some View {
        let tank = viewModel.tanks[index]
        let percent = max(min(tank.gallons / tank.capacity, 1), 0)
        let color = viewModel.editingTankIndex == index ? Color.red :
            viewModel.lastActiveTankIndex == index ?
            Color.blue : Color.gray
        
        VStack {
            Button {
                if viewModel.editingTankIndex != index {
                    selectedTankIndex = index
                    usedInput = "5"
                    showSwitchSheet = true
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                    
                    Circle()
                        .trim(from: 0, to: percent)
                        .stroke(
                            color,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    
                    Text(String(format: "%.0f", viewModel.tanks[index].gallons))
                        .font(.title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(6)
                }
                // Shrink to fit narrow screens (e.g. the outside display), up to 80pt.
                .frame(maxWidth: 80)
                .aspectRatio(1, contentMode: .fit)
                .padding(2)
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        viewModel.startEditingTank(index: index)
                        showEditSheet = true
                    }
            )
            
            Text(viewModel.tanks[index].name)
                .font(.caption)
        }
        .frame(maxWidth: .infinity)
    }

    var body: some View {
        VStack(spacing: 30) {
            Text("Fuel Tracker")
                .font(.largeTitle)
                .padding(.top)

            HStack(spacing: 8) {
                ForEach(viewModel.tanks.indices, id: \.self) { index in
                    tankButton(for: index)
                }
            }

            HStack(spacing: 8) {
                VStack(alignment: .center, spacing: 4) {
                    Text("Used")
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f", viewModel.totalUsedGallons ?? 0))
                        .font(.title)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .frame(maxWidth: .infinity)
                
                VStack(alignment: .center, spacing: 4) {
                    Text("Remaining")
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f", viewModel.totalRemainingGallons()))
                        .font(.title)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .frame(maxWidth: .infinity)
           
                VStack(alignment: .center, spacing: 4) {
                    Text("Endurance")
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundColor(.secondary)
                    Text(viewModel.enduranceText)
                        .font(.title)
                        .monospacedDigit()
                        .foregroundColor(viewModel.enduranceHours < 1 ? .red : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .center, spacing: 4) {
                    Text("-45 Reserve")
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundColor(.secondary)
                    Text(viewModel.enduranceMinusReserveText)
                        .font(.title)
                        .monospacedDigit()
                        .foregroundColor(viewModel.enduranceHours < 1 ? .red : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
            
            
            Button("Reset Used"){
                viewModel.totalUsedGallons = nil
                viewModel.saveState()
            }.buttonStyle(.bordered)
            
            if !viewModel.lastSwitchText.isEmpty {
                Text(viewModel.lastSwitchText)
                    .font(.caption)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
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
        .sheet(isPresented: $showSwitchSheet) {
                VStack(spacing: 20) {
                    Text("Enter Fuel Used")
                        .font(.headline)
                        .padding(.top)
                    
                    TextField("Gallons", text: $usedInput)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .focused($isInputFocused)
                    
                    HStack(spacing: 20) {
                        Button("Cancel") {
                            showSwitchSheet = false
                        }
                        .buttonStyle(.bordered)
                        
                        Button("OK") {
                            if let idx = selectedTankIndex,
                               let usedVal = Double(usedInput) {
                                viewModel.switchToTank(at: idx, newTotalUsed: usedVal)
                            }
                            showSwitchSheet = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.bottom)
                }
                .presentationDetents([.medium])
                .background(Color(.systemBackground))
                .onAppear {
                    usedInput = String(format:"%.1f", viewModel.totalUsedGallons == nil ? 0 : viewModel.totalUsedGallons! + 5)
                    isInputFocused = true
                }
            }
        .padding()
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
