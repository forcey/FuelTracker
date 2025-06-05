import SwiftUI
import Combine

@MainActor
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
    @Published var lastSwitchDate: Date? = nil
    @Published var currentDate: Date = Date()
    @Published var totalUsedGallons : Double? = nil
    @Published var editingTankIndex: Int? = nil

    private var timerSubscription: AnyCancellable?

    init() {
        timerSubscription = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                self?.currentDate = now
            }
    }

    deinit {
        timerSubscription?.cancel()
    }

    func switchToTank(at index: Int, newTotalUsed: Double) {
        guard tanks.indices.contains(index) else { return }
        if let lastIndex = lastActiveTankIndex {
            let tankUsed = newTotalUsed - (totalUsedGallons ?? 0)
            tanks[lastIndex].gallons = max(tanks[lastIndex].gallons - tankUsed, 0)
            lastFromIndex = lastIndex
            lastToIndex = index
            totalUsedGallons = newTotalUsed
            lastSwitchDate = Date.now
            currentDate = Date.now
        }
        lastActiveTankIndex = index
    }

    func totalRemainingGallons() -> Double {
        tanks.reduce(0) { $0 + $1.gallons }
    }

    var lastSwitchText: String {
        guard
            let from = lastFromIndex,
            let to = lastToIndex,
            let used = totalUsedGallons,
            let date = lastSwitchDate
        else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let relative = formatter.localizedString(for: date, relativeTo: currentDate)
        return "Last switched from \(tanks[from].name) to \(tanks[to].name) \(relative) at \(String(format: "%.1f", used)) gal used"
    }

    func startEditingTank(index: Int) {
        editingTankIndex = index
    }

    func stopEditingTank() {
        editingTankIndex = nil
    }
}
