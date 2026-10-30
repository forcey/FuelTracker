import SwiftUI
import Combine

@MainActor
class FuelViewModel: ObservableObject {
    private struct StoredState: Codable {
        var tankGallons: [Double]
        var lastActiveTankIndex: Int?
        var lastFromIndex: Int?
        var lastToIndex: Int?
        var lastSwitchDate: Date?
        var totalUsedGallons: Double?
        var isInFlight: Bool?
    }

    private let storageKey = "FuelTrackerState"

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
    /// Preflight: set tank levels on the ground; the endurance timer is stopped.
    /// In flight: switch tanks; the timer always runs.
    @Published var isInFlight = false

    private var timerSubscription: AnyCancellable?
    private var tankSubscriptions: [AnyCancellable] = []

    init() {
        timerSubscription = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                self?.currentDate = now
            }
        // Tanks are reference types, so changing a tank's gallons doesn't
        // publish a change to `tanks`. Forward each tank's changes so views
        // update immediately instead of on the next timer tick.
        tankSubscriptions = tanks.map { tank in
            tank.objectWillChange.sink { [weak self] _ in
                self?.objectWillChange.send()
            }
        }
        loadState()
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
        saveState()
    }

    func totalRemainingGallons() -> Double {
        tanks.reduce(0) { $0 + $1.gallons }
    }

    private func hoursElapsedSinceLastSwitch() -> Double {
        guard isInFlight, let lastDate = lastSwitchDate else { return 0 }
        return max(currentDate.timeIntervalSince(lastDate), 0) / 3600
    }

    /// Whether endurance is counting down: always in flight, until fuel runs out.
    var isTimerRunning: Bool {
        isInFlight && enduranceHours > 0
    }

    /// Entering flight starts the clock from now, from the levels set in
    /// preflight. Going back to preflight stops it.
    func setInFlight(_ flying: Bool) {
        guard flying != isInFlight else { return }
        if flying {
            lastSwitchDate = Date.now
            currentDate = Date.now
            lastFromIndex = nil
            lastToIndex = nil
        }
        isInFlight = flying
        saveState()
    }

    var enduranceHours: Double {
        let burnRate = 12.0
        let totalHours = totalRemainingGallons() / burnRate
        return max(totalHours - hoursElapsedSinceLastSwitch(), 0)
    }

    var enduranceMinusReserveHours: Double {
        max(enduranceHours - 0.75, 0)
    }

    private func formatTime(hours: Double) -> String {
        guard hours.isFinite && hours > 0 else { return "0:00" }
        let totalMinutes = Int((hours * 60).rounded())
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return String(format: "%d:%02d", h, m)
    }

    var enduranceText: String { formatTime(hours: enduranceHours) }

    var enduranceMinusReserveText: String {
        formatTime(hours: enduranceMinusReserveHours)
    }

    /// "RM → LM · 8 min. ago", or empty before the first switch.
    var lastSwitchText: String {
        guard
            let from = lastFromIndex,
            let to = lastToIndex,
            totalUsedGallons != nil,
            let date = lastSwitchDate
        else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        // currentDate only ticks every 5s, so it can trail a fresh switch; avoid "in 0s".
        let relative = formatter.localizedString(for: date, relativeTo: max(currentDate, date))
        return "\(tanks[from].name) → \(tanks[to].name) · \(relative)"
    }

    func startEditingTank(index: Int) {
        editingTankIndex = index
    }

    func stopEditingTank() {
        editingTankIndex = nil
    }

    func saveState() {
        let state = StoredState(
            tankGallons: tanks.map { $0.gallons },
            lastActiveTankIndex: lastActiveTankIndex,
            lastFromIndex: lastFromIndex,
            lastToIndex: lastToIndex,
            lastSwitchDate: lastSwitchDate,
            totalUsedGallons: totalUsedGallons,
            isInFlight: isInFlight
        )
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func loadState() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        if let state = try? JSONDecoder().decode(StoredState.self, from: data) {
            for (index, gallons) in state.tankGallons.enumerated() where tanks.indices.contains(index) {
                tanks[index].gallons = gallons
            }
            lastActiveTankIndex = state.lastActiveTankIndex
            lastFromIndex = state.lastFromIndex
            lastToIndex = state.lastToIndex
            lastSwitchDate = state.lastSwitchDate
            totalUsedGallons = state.totalUsedGallons
            isInFlight = state.isInFlight ?? false
        }
    }

    func fillAllTanks() {
        for tank in tanks {
            tank.gallons = tank.capacity
        }
        saveState()
    }
}
