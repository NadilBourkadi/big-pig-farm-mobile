/// HUDButtonTests — Structural tests for the shared HUDButton component.
import Testing
@testable import BigPigFarm

@Suite("HUDButton")
struct HUDButtonTests {

    @Test("Default isActive is false")
    func defaultIsActiveFalse() {
        let button = HUDButton(systemImage: "star", label: "Test", action: {})
        #expect(button.isActive == false)
    }

    @Test("Default isDisabled is false")
    func defaultIsDisabledFalse() {
        let button = HUDButton(systemImage: "star", label: "Test", action: {})
        #expect(button.isDisabled == false)
    }

    @Test("isActive can be set to true")
    func isActiveTrue() {
        let button = HUDButton(systemImage: "star", label: "Test", isActive: true, action: {})
        #expect(button.isActive == true)
    }

    @Test("isDisabled can be set to true")
    func isDisabledTrue() {
        let button = HUDButton(
            systemImage: "star",
            label: "Test",
            isDisabled: true,
            action: {}
        )
        #expect(button.isDisabled == true)
    }

    @Test("Both isActive and isDisabled can be true simultaneously")
    func activeAndDisabledCombination() {
        let button = HUDButton(
            systemImage: "pencil",
            label: "Edit",
            isActive: true,
            isDisabled: true,
            action: {}
        )
        #expect(button.isActive == true)
        #expect(button.isDisabled == true)
    }

    @Test("Stores systemImage and label correctly")
    func storesProperties() {
        let button = HUDButton(
            systemImage: "cart.fill",
            label: "Shop",
            action: {}
        )
        #expect(button.systemImage == "cart.fill")
        #expect(button.label == "Shop")
    }
}
