/// DisplayFormattingTests — Tests for free formatting functions and color mappings.
/// SwiftUI view rendering is deferred to the polish phase per spec.
import Testing
import Foundation
import SwiftUI
import UIKit
@testable import BigPigFarm

// MARK: - formatBreedingStatus

struct FormatBreedingStatusTests {

    // ageDays=25 (adult), default happiness=75 >= 70 threshold, not locked → Ready
    @Test func adultHealthyPigIsReady() {
        var pig = GuineaPig.create(name: "Test", gender: .male)
        pig.ageDays = 25.0
        #expect(formatBreedingStatus(pig) == "Ready")
    }

    @Test func lockedPigShowsLocked() {
        var pig = GuineaPig.create(name: "Test", gender: .male)
        pig.ageDays = 25.0
        pig.breedingLocked = true
        #expect(formatBreedingStatus(pig) == "LOCKED")
    }

    @Test func babyPigShowsBaby() {
        let pig = GuineaPig.create(name: "Test", gender: .male) // ageDays=0 by default
        #expect(formatBreedingStatus(pig) == "Baby")
    }

    @Test func babyMarkedForSaleShowsSellAtAdult() {
        var pig = GuineaPig.create(name: "Test", gender: .male)
        pig.markedForSale = true
        // isBaby=true (ageDays=0), markedForSale=true → special case
        #expect(formatBreedingStatus(pig) == "Sell@Adult")
    }

    @Test func seniorPigShowsSenior() {
        var pig = GuineaPig.create(name: "Test", gender: .male)
        pig.ageDays = 175.0 // seniorAgeDays=150
        #expect(formatBreedingStatus(pig) == "Senior")
    }

    @Test func pregnantPigShowsPregnant() {
        var pig = GuineaPig.create(name: "Test", gender: .female)
        pig.ageDays = 25.0
        pig.isPregnant = true
        pig.pregnancyDays = 1.0
        #expect(formatBreedingStatus(pig) == "Pregnant")
    }

    @Test func verboseLockedShowsFullReason() {
        var pig = GuineaPig.create(name: "Test", gender: .male)
        pig.ageDays = 25.0
        pig.breedingLocked = true
        #expect(formatBreedingStatus(pig, verbose: true) == "Breeding locked")
    }

    @Test func verboseBabyMarkedForSaleShowsFullMessage() {
        var pig = GuineaPig.create(name: "Test", gender: .male)
        pig.markedForSale = true
        #expect(formatBreedingStatus(pig, verbose: true) == "Marked for auto-sell at adulthood")
    }

    @Test func unhappyPigShowsNotReady() {
        var pig = GuineaPig.create(name: "Test", gender: .male)
        pig.ageDays = 25.0
        pig.needs.happiness = 50.0 // below 70 threshold
        #expect(formatBreedingStatus(pig) == "Not ready")
    }
}

// MARK: - formatFacilityBonuses

struct FormatFacilityBonusesTests {

    @Test func groomingStationShowsSaleBonus() {
        let bonuses = formatFacilityBonuses(.groomingStation)
        #expect(bonuses.contains("sale"))
        #expect(bonuses.contains("15"))
    }

    @Test func hideoutShowsHappinessBonus() {
        let bonuses = formatFacilityBonuses(.hideout)
        #expect(bonuses.contains("happiness"))
        #expect(bonuses.contains("10"))
    }

    @Test func foodBowlHasNoBonuses() {
        let bonuses = formatFacilityBonuses(.foodBowl)
        #expect(bonuses.isEmpty)
    }

    @Test func veggieGardenShowsFoodProduction() {
        let bonuses = formatFacilityBonuses(.veggieGarden)
        #expect(bonuses.contains("produces"))
        #expect(bonuses.contains("10"))
    }

    @Test func therapyGardenShowsMultipleBonuses() {
        let bonuses = formatFacilityBonuses(.therapyGarden)
        // therapyGarden: healthBonus=0.08, happinessBonus=0.20
        #expect(bonuses.contains("health"))
        #expect(bonuses.contains("happiness"))
        #expect(bonuses.contains(", "))
    }

    @Test func waterBottleHasNoBonuses() {
        let bonuses = formatFacilityBonuses(.waterBottle)
        #expect(bonuses.isEmpty)
    }
}

// MARK: - pigColorSwiftUI

struct PigColorSwiftUITests {

    @Test func allColorsResolveFromAssetCatalog() {
        // Each BaseColor must map to a named color in the asset catalog.
        // A missing colorset silently returns a transparent color, so we
        // convert to UIColor and verify alpha > 0 for each case.
        // Use getRed (not getWhite) — getWhite only works for greyscale colors.
        for baseColor in BaseColor.allCases {
            let color = pigColorSwiftUI(baseColor)
            let uiColor = UIColor(color)
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            #expect(alpha > 0, "PigColor\(baseColor.rawValue.capitalized) not found in asset catalog")
        }
    }

    @Test func colorNameMatchesRawValueCapitalized() {
        // Verify the string construction: "PigColor" + rawValue.capitalized
        // guards against a refactor breaking the naming convention.
        #expect("PigColor\(BaseColor.black.rawValue.capitalized)" == "PigColorBlack")
        #expect("PigColor\(BaseColor.blue.rawValue.capitalized)" == "PigColorBlue")
        #expect("PigColor\(BaseColor.cream.rawValue.capitalized)" == "PigColorCream")
    }
}
