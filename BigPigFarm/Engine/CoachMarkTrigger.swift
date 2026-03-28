/// CoachMarkTrigger — Evaluates game state to determine which coach mark to show.
///
/// Stateless namespace (caseless enum). All methods are pure functions.
/// Evaluated from ContentView when the overlay is rendered, not per-tick.
///
/// Maps from: N/A (new for mobile)
import Foundation

// MARK: - CoachMarkAnchor

enum CoachMarkAnchor: Sendable {
    case toolbarButton(label: String)
    case farmScene
}

// MARK: - CoachMarkTrigger

enum CoachMarkTrigger {

    /// Returns the highest-priority unshown coach mark, or nil.
    ///
    /// Priority order matches `CoachMarkID.allCases` declaration order.
    /// First match wins — only one coach mark shows at a time.
    @MainActor
    static func evaluate(state: GameState, coachState: CoachMarkState) -> CoachMarkID? {
        for id in CoachMarkID.allCases {
            guard !coachState.isShown(id) else { continue }
            if isMet(id, state: state) {
                return id
            }
        }
        return nil
    }

    /// Display text for a coach mark.
    static func message(for id: CoachMarkID) -> String {
        switch id {
        case .welcomeTapPig:
            "Tap a pig to see their details, name, and needs"
        case .openShop:
            "Open the Shop to buy new facilities for your pigs"
        case .refillFacilities:
            "Your facilities are running low — tap Refill to top them up"
        case .breedingReady:
            "Your pigs are ready to breed — open Breeding to get started"
        case .editMode:
            "Tap Edit to rearrange or remove facilities"
        case .firstSale:
            "You have plenty of pigs — open the Shop to sell some"
        }
    }

    /// The SF Symbol icon for the coach mark.
    static func icon(for id: CoachMarkID) -> String {
        switch id {
        case .welcomeTapPig: "hand.tap"
        case .openShop: "storefront"
        case .refillFacilities: "drop.fill"
        case .breedingReady: "heart.fill"
        case .editMode: "pencil"
        case .firstSale: "dollarsign.circle"
        }
    }

    /// Where the bubble should conceptually point.
    static func anchor(for id: CoachMarkID) -> CoachMarkAnchor {
        switch id {
        case .welcomeTapPig: .farmScene
        case .openShop: .toolbarButton(label: "Shop")
        case .refillFacilities: .toolbarButton(label: "Refill")
        case .breedingReady: .toolbarButton(label: "Breeding")
        case .editMode: .toolbarButton(label: "Edit")
        case .firstSale: .toolbarButton(label: "Shop")
        }
    }

    // MARK: - Private

    @MainActor
    private static func isMet(_ id: CoachMarkID, state: GameState) -> Bool {
        switch id {
        case .welcomeTapPig:
            state.gameTime.totalGameMinutes < 5 && state.pigCount >= 2

        case .openShop:
            state.gameTime.totalGameMinutes >= 10 && state.facilities.count <= 3

        case .refillFacilities:
            anyFacilityBelowThreshold(state: state, threshold: 30)

        case .breedingReady:
            adultCount(state: state) >= 2 && !state.breedingProgram.enabled

        case .editMode:
            state.facilities.count >= 5

        case .firstSale:
            state.totalPigsBorn >= 3 && state.totalPigsSold == 0
        }
    }

    @MainActor
    private static func anyFacilityBelowThreshold(state: GameState, threshold: Double) -> Bool {
        state.facilities.values.contains { facility in
            facility.info.refillCost > 0 && facility.fillPercentage < threshold
        }
    }

    @MainActor
    private static func adultCount(state: GameState) -> Int {
        state.guineaPigs.values.filter(\.isAdult).count
    }
}
