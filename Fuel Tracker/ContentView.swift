//
//  ContentView.swift
//  Fuel Tracker
//
//  Created by Todd Li on 6/1/25.
//

import SwiftUI
import Combine

// Base Tank class
class Tank: Identifiable, ObservableObject {
    let id = UUID()
    let name: String
    @Published var gallons: Double
    let capacity: Double
    let maxFuelHawkReading: Double
    
    init(name: String, capacity: Double, initialGallons: Double, maxFuelHawkReading: Double) {
        self.name = name
        self.capacity = capacity
        self.gallons = initialGallons
        self.maxFuelHawkReading = maxFuelHawkReading
    }
    
    // Default conversion (to be overridden)
    func convertFuelHawk(_ reading: Double) -> Double {
        return 0
    }
}

// Main tank subclass with its own conversion formula
class MainTank: Tank {
    init(name: String, initialGallons: Double) {
        super.init(name: name, capacity: 25, initialGallons: initialGallons, maxFuelHawkReading: 13.5)
    }
    
    override func convertFuelHawk(_ reading: Double) -> Double {
        if reading == 0 { return 0 }
        if reading == 13.5 { return 25 }
        return -0.0838 * reading * reading + 2.95 * reading + 0.356
    }
}

// Aux tank subclass with its own conversion formula
class AuxTank: Tank {
    init(name: String, initialGallons: Double) {
        super.init(name: name, capacity: 17, initialGallons: initialGallons, maxFuelHawkReading: 13)
    }
    
    override func convertFuelHawk(_ reading: Double) -> Double {
        if reading == 0 { return 0 }
        if reading == 13.0 { return 17 }
        return -0.013 * reading * reading + 1.49 * reading - 0.0792
    }
}

class FuelViewModel: ObservableObject {
    @Published var tanks: [Tank] = [
        AuxTank(name: "LT", initialGallons: 12),
        MainTank(name: "LM", initialGallons: 15),
        MainTank(name: "RM", initialGallons: 17),
        AuxTank(name: "RT", initialGallons: 13)
    ]
    @Published var lastActiveTankIndex: Int? = nil
    @Published var lastFromIndex: Int? = nil
    @Published var lastToIndex: Int? = nil
    @Published var lastUsedAmount: Double? = nil
    @Published var lastSwitchDate: Date? = nil
    @Published var currentDate: Date = Date()
    
    private var timerSubscription: AnyCancellable?
    
    init() {
        timerSubscription = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                self?.currentDate = now
            }
    }
    
    func switchToTank(index: Int, used: Double) {
        guard index >= 0 && index < tanks.count else { return }
        if let lastIndex = lastActiveTankIndex {
            // Subtract used from previous tank
            tanks[lastIndex].gallons = max(tanks[lastIndex].gallons - used, 0)
            lastFromIndex = lastIndex
            lastToIndex = index
            lastUsedAmount = used
            lastSwitchDate = Date()
            currentDate = Date()
        }
        lastActiveTankIndex = index
    }
    
    var lastSwitchText: String {
        guard
            let from = lastFromIndex,
            let to = lastToIndex,
            let used = lastUsedAmount,
            let date = lastSwitchDate
        else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let relative = formatter.localizedString(for: date, relativeTo: currentDate)
        return "Last switched from \(tanks[from].name) to \(tanks[to].name) \(relative) at \(String(format: "%.1f", used)) gal used"
    }
}

// TankEditor component
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
            // Upper scale (gallons)
            HStack {
                ForEach(tickerRange, id: \.self) { reading in
                    let gallons = tank.convertFuelHawk(reading)
                    Text(String(format: "%.0f", gallons))
                        .frame(maxWidth: .infinity)
                        .font(.caption2)
                }
                Text("gal").font(.caption2).frame(width:30)
            }
            
            // Slider
            Slider(value: $sliderReading, in: 0...tank.maxFuelHawkReading, step: 0.1, onEditingChanged: { editing in
                if editing {
                    self.hasMovedSlider = true
                }
            })
            
            // Lower scale (FuelHawk)
            HStack {
                ForEach(tickerRange, id: \.self) { reading in
                    Text(String(format: "%.0f", reading))
                        .frame(maxWidth: .infinity)
                        .font(.caption2)
                }
                Text("Fuel\nHawk").font(.caption2).frame(width:30)
            }
            
            Text(String(format:"%.1f FuelHawk / %.1f gallons", sliderReading, tank.convertFuelHawk(sliderReading)))
            
            // Reset button
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

struct ContentView: View {
    @StateObject private var viewModel = FuelViewModel()
    @State private var showSwitchAlert = false
    @State private var selectedTankIndex: Int? = nil
    @State private var usedInput: String = "5"
    @State private var editingTankIndex: Int? = nil
    @State private var hasMovedSlider: Bool = false
    
    private var currentTank: Tank? {
        if let idx = viewModel.lastActiveTankIndex {
            return viewModel.tanks[idx]
        }
        return nil
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Fuel Tracker")
                .font(.largeTitle)
                .padding(.top)
            
            // Tank circles
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
                                    hasMovedSlider = false
                                }
                        )
                        Text(viewModel.tanks[index].name)
                            .font(.caption)
                    }
                }
            }
            
            // Tank Editor component
            if let idx = editingTankIndex {
                TankEditor(
                    tank: viewModel.tanks[idx],
                    editingTankIndex: $editingTankIndex,
                )
            }
            
            // Last switch info
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
            // Set an initial active tank if none selected
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
