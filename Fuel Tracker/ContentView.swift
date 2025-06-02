//
//  ContentView.swift
//  Fuel Tracker
//
//  Created by Todd Li on 6/1/25.
//

import SwiftUI

struct Tank: Identifiable {
    let id = UUID()
    let name: String
    var gallons: Double
}

class FuelViewModel: ObservableObject {
    @Published var tanks: [Tank] = [
        Tank(name: "LT", gallons: 12),
        Tank(name: "LM", gallons: 15),
        Tank(name: "RM", gallons: 17),
        Tank(name: "RT", gallons: 13)
    ]
    @Published var lastActiveTankIndex: Int? = nil
    @Published var lastFromIndex: Int? = nil
    @Published var lastToIndex: Int? = nil
    @Published var lastUsedAmount: Double? = nil
    @Published var lastSwitchDate: Date? = nil
        
    func convertFuelHawk(_ reading: Double) -> Double {
        if reading == 0 { return 0 }
        if reading == 13.5 { return 25 }
        return -0.0838 * reading * reading + 2.95 * reading + 0.356
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
        let relative = formatter.localizedString(for: date, relativeTo: Date())
        return "Last switched from \(tanks[from].name) to \(tanks[to].name) \(relative) at \(String(format: "%.1f", used)) gal used"
    }
}

struct ContentView: View {
    @StateObject private var viewModel = FuelViewModel()
    @State private var showSwitchAlert = false
    @State private var selectedTankIndex: Int? = nil
    @State private var usedInput: String = ""
    
    @State private var sliderReading: Double = 0.0
    @State private var hasMovedSlider: Bool = false
    @State private var buttonText: String = "Reset Amount"
    
    private let sliderRange: ClosedRange<Double> = 0...13.5
    private let tickReadings: [Double] = [0,3,6,9,12]
    
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
                            selectedTankIndex = index
                            usedInput = ""
                            showSwitchAlert = true
                        }) {
                            ZStack {
                                Circle()
                                    .stroke(viewModel.lastActiveTankIndex == index ? Color.blue : Color.gray, lineWidth: 3)
                                    .frame(width: 80, height: 80)
                                Text(String(format: "%.0f", viewModel.tanks[index].gallons))
                                    .font(.title)
                            }
                        }
                        Text(viewModel.tanks[index].name)
                            .font(.caption)
                    }
                }
            }
            
            // Slider with dual scales
            VStack(spacing: 10) {
                // Upper scale (gallons)
                HStack {
                    ForEach(tickReadings, id: \.self) { reading in
                        let gallons = viewModel.convertFuelHawk(reading)
                        Text(String(format: "%.0f", gallons))
                            .frame(maxWidth: .infinity)
                            .font(.caption2)
                    }
                    Text("gal").font(.caption2).frame(width:30)
                }
                // Slider
                Slider(value: $sliderReading, in: sliderRange, step: 0.1, onEditingChanged: { editing in
                    if editing {
                        hasMovedSlider = true
                    }
                })
                
                // Lower scale (FuelHawk)
                HStack {
                    ForEach(tickReadings, id: \.self) { reading in
                        Text(String(format: "%.0f", reading))
                            .frame(maxWidth: .infinity)
                            .font(.caption2)
                    }
                    Text("Fuel\nHawk").font(.caption2).frame(width:30)
                }
                
                Text(String(format:"%.1f FuelHawk / %.1f gallons", sliderReading, viewModel.convertFuelHawk(sliderReading)))

                // Reset button
                Button(action: {
                    if let idx = viewModel.lastActiveTankIndex {
                        let newGallons = viewModel.convertFuelHawk(sliderReading)
                        viewModel.tanks[idx].gallons = newGallons
                        hasMovedSlider = false
                    }
                }) {
                    Text("Reset Amount")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(hasMovedSlider ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(!hasMovedSlider || viewModel.lastActiveTankIndex == nil)
            }
            .padding(.horizontal)
            
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
