import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = FuelViewModel()
    @State private var selectedTankIndex: Int? = nil
    @State private var usedInput: String = "5"
    @State private var showEditSheet = false
    @State private var showSwitchSheet = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 30) {
            Text("Fuel Tracker")
                .font(.largeTitle)
                .padding(.top)

            HStack(spacing: 20) {
                ForEach(viewModel.tanks.indices, id: \.self) { index in
                    VStack {
                        Button(action: {
                            if viewModel.editingTankIndex != index {
                                selectedTankIndex = index
                                usedInput = "5"
                                showSwitchSheet = true
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .stroke(
                                        viewModel.editingTankIndex == index ? Color.red :
                                            viewModel.lastActiveTankIndex == index ? Color.blue : Color.gray,
                                        lineWidth: 3
                                    )
                                    .frame(width: 80, height: 80)
                                Text(String(format: "%.0f", viewModel.tanks[index].gallons))
                                    .font(.title)
                            }
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
                }
            }

            HStack(spacing: 40) {
                VStack(alignment: .center, spacing: 4) {
                    Text("Used")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f", viewModel.totalUsedGallons ?? 0))
                        .font(.title)
                        .monospacedDigit()
                }
                
                VStack(alignment: .center, spacing: 4) {
                    Text("Remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f", viewModel.totalRemainingGallons()))
                        .font(.title)
                        .monospacedDigit()
                }
                
                Button(action: {
                    viewModel.totalUsedGallons = nil
                }) {
                    Text("Reset")
                        .font(.caption)
                        .padding(.horizontal)
                        .padding(.vertical)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
            

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
                            if let idx = selectedTankIndex, let usedVal = Double(usedInput) {
                                viewModel.switchToTank(index: idx, newUsed: usedVal)
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
