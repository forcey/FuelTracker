import SwiftUI

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

    func convertFuelHawk(_ reading: Double) -> Double {
        0
    }
}

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
