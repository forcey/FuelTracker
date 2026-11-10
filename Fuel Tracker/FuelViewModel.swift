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
        /// When this state was saved, so the newest copy wins between
        /// this device's UserDefaults and iCloud.
        var savedAt: Date?
    }

    private let storageKey = "FuelTrackerState"
    /// Synced to the user's other devices through iCloud key-value storage.
    private let cloud = NSUbiquitousKeyValueStore.default
    private var lastSavedAt: Date = .distantPast

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
    private var tankSubscriptions: [AnyCancellable] = []
    private var cloudSubscription: AnyCancellable?

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
        cloudSubscription = NotificationCenter.default
            .publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: cloud)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadState()
            }
        cloud.synchronize()
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
        guard let lastDate = lastSwitchDate, totalUsedGallons != nil else { return 0 }
        return currentDate.timeIntervalSince(lastDate) / 3600
    }

    /// Whether endurance is counting down: starts at the first tank switch,
    /// stops on Reset Used or when fuel runs out.
    var isTimerRunning: Bool {
        lastSwitchDate != nil && totalUsedGallons != nil && enduranceHours > 0
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
        let now = Date()
        let state = StoredState(
            tankGallons: tanks.map { $0.gallons },
            lastActiveTankIndex: lastActiveTankIndex,
            lastFromIndex: lastFromIndex,
            lastToIndex: lastToIndex,
            lastSwitchDate: lastSwitchDate,
            totalUsedGallons: totalUsedGallons,
            savedAt: now
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        lastSavedAt = now
        UserDefaults.standard.set(data, forKey: storageKey)
        cloud.set(data, forKey: storageKey)
    }

    /// Loads the newer of this device's saved state and iCloud's, if it's
    /// newer than what's already showing.
    func loadState() {
        let candidates = [
            UserDefaults.standard.data(forKey: storageKey),
            cloud.data(forKey: storageKey)
        ].compactMap { $0.flatMap { try? JSONDecoder().decode(StoredState.self, from: $0) } }
        guard
            let state = candidates.max(by: { ($0.savedAt ?? .distantPast) < ($1.savedAt ?? .distantPast) }),
            (state.savedAt ?? .distantPast) > lastSavedAt || lastSavedAt == .distantPast
        else { return }

        for (index, gallons) in state.tankGallons.enumerated() where tanks.indices.contains(index) {
            tanks[index].gallons = gallons
        }
        lastActiveTankIndex = state.lastActiveTankIndex
        lastFromIndex = state.lastFromIndex
        lastToIndex = state.lastToIndex
        lastSwitchDate = state.lastSwitchDate
        totalUsedGallons = state.totalUsedGallons
        currentDate = Date()
        lastSavedAt = state.savedAt ?? .distantPast

        // Keep the local copy current so it's there offline.
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func fillAllTanks() {
        for tank in tanks {
            tank.gallons = tank.capacity
        }
        saveState()
    }
}
