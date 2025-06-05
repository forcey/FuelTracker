import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = FuelViewModel()
    @State private var showSwitchAlert = false
    @State private var selectedTankIndex: Int? = nil
    @State private var usedInput: String = "5"
    @State private var editingTankIndex: Int? = nil

    var body: some View {
        VStack(spacing: 30) {
            Text("Fuel Tracker")
                .font(.largeTitle)
                .padding(.top)

            HStack(spacing: 20) {
                ForEach(viewModel.tanks.indices, id: \.self) { index in
                    VStack {
                        Button(action: {
                            if editingTankIndex != index {
                                selectedTankIndex = index
                                usedInput = "5"
                                showSwitchAlert = true
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .stroke(
                                        editingTankIndex == index ? Color.red :
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
                                    editingTankIndex = index
                                }
                        )
                        Text(viewModel.tanks[index].name)
                            .font(.caption)
                    }
                }
            }

            if let idx = editingTankIndex {
                TankEditor(
                    tank: viewModel.tanks[idx],
                    editingTankIndex: $editingTankIndex
                )
            }

            Text(String(format: "%.1f gallons remaining", viewModel.totalRemainingGallons()))

            if !viewModel.lastSwitchText.isEmpty {
                Text(viewModel.lastSwitchText)
                    .font(.caption)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .alert(isPresented: $showSwitchAlert) {
            Alert(
                title: Text("Fuel Used"),
                message: Text("Enter fuel used from previous tank (gallons)"),
                primaryButton: .default(Text("OK"), action: {
                    if let idx = selectedTankIndex, let usedVal = Double(usedInput) {
                        viewModel.switchToTank(index: idx, used: usedVal)
                    }
                }),
                secondaryButton: .cancel()
            )
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
