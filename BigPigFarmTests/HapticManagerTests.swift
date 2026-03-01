/// HapticManagerTests — Smoke tests confirming each HapticManager method is callable
/// without crashing. UIKit feedback generators no-op in simulator/test environments.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - HapticManager Smoke Tests

@Test @MainActor func hapticPigSelectedDoesNotCrash() {
    HapticManager.pigSelected()
}

@Test @MainActor func hapticPurchaseDoesNotCrash() {
    HapticManager.purchase()
}

@Test @MainActor func hapticPigSoldDoesNotCrash() {
    HapticManager.pigSold()
}

@Test @MainActor func hapticBirthDoesNotCrash() {
    HapticManager.birth()
}

@Test @MainActor func hapticPigdexDiscoveryDoesNotCrash() {
    HapticManager.pigdexDiscovery()
}

@Test @MainActor func hapticContractCompletedDoesNotCrash() {
    HapticManager.contractCompleted()
}

@Test @MainActor func hapticErrorDoesNotCrash() {
    HapticManager.error()
}

// MARK: - Repeated Calls

@Test @MainActor func hapticMethodsAreIdempotent() {
    // Calling repeatedly in the same tick must not crash or accumulate state.
    for _ in 0..<5 {
        HapticManager.pigSelected()
        HapticManager.purchase()
        HapticManager.pigSold()
        HapticManager.birth()
        HapticManager.pigdexDiscovery()
        HapticManager.contractCompleted()
        HapticManager.error()
    }
}
