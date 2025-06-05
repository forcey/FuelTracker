import SwiftUI
import Combine

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
            tanks[lastIndex].gallons = max(tanks[lastIndex].gallons - used, 0)
            lastFromIndex = lastIndex
            lastToIndex = index
            lastUsedAmount = used
            lastSwitchDate = Date()
            currentDate = Date()
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
            let used = lastUsedAmount,
            let date = lastSwitchDate
        else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let relative = formatter.localizedString(for: date, relativeTo: currentDate)
        return "Last switched from \(tanks[from].name) to \(tanks[to].name) \(relative) at \(String(format: "%.1f", used)) gal used"
    }
}
