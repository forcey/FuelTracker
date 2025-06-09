//
//  Fuel_TrackerTests.swift
//  Fuel TrackerTests
//
//  Created by Todd Li on 6/1/25.
//

import XCTest
@testable import Fuel_Tracker

final class Fuel_TrackerTests: XCTestCase {

    func testMainTankConversion() {
        let tank = MainTank(name: "Test", initialGallons: 0)
        XCTAssertEqual(tank.convertFuelHawk(0), 0, accuracy: 0.0001)
        XCTAssertEqual(tank.convertFuelHawk(tank.maxFuelHawkReading), tank.capacity, accuracy: 0.0001)
        let reading = tank.maxFuelHawkReading / 2
        let expected = -0.0838 * reading * reading + 2.95 * reading + 0.356
        XCTAssertEqual(tank.convertFuelHawk(reading), expected, accuracy: 0.0001)
    }

    func testAuxTankConversion() {
        let tank = AuxTank(name: "Test", initialGallons: 0)
        XCTAssertEqual(tank.convertFuelHawk(0), 0, accuracy: 0.0001)
        XCTAssertEqual(tank.convertFuelHawk(tank.maxFuelHawkReading), tank.capacity, accuracy: 0.0001)
        let reading = tank.maxFuelHawkReading / 2
        let expected = -0.013 * reading * reading + 1.49 * reading - 0.0792
        XCTAssertEqual(tank.convertFuelHawk(reading), expected, accuracy: 0.0001)
    }

    @MainActor
    func testSwitchToTankUpdatesState() {
        let vm = FuelViewModel()
        vm.lastActiveTankIndex = 0
        vm.totalUsedGallons = 0
        vm.switchToTank(at: 1, newTotalUsed: 5)
        XCTAssertEqual(vm.tanks[0].gallons, 7, accuracy: 0.0001)
        XCTAssertEqual(vm.lastFromIndex, 0)
        XCTAssertEqual(vm.lastToIndex, 1)
        XCTAssertEqual(vm.totalUsedGallons!, 5, accuracy: 0.0001)
        XCTAssertEqual(vm.lastActiveTankIndex, 1)
    }

    @MainActor
    func testEnduranceCalculation() {
        let vm = FuelViewModel()
        vm.tanks.forEach { $0.gallons = 14 }
        vm.currentDate = Date()
        vm.lastSwitchDate = vm.currentDate.addingTimeInterval(-3600)
        let expected = vm.totalRemainingGallons() / 14 - 1
        XCTAssertEqual(vm.enduranceHours, expected, accuracy: 0.0001)
        XCTAssertEqual(vm.enduranceMinusReserveHours, max(expected - 0.75, 0), accuracy: 0.0001)
    }
}
