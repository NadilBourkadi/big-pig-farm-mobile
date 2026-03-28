/// ShopViewModel — Purchase logic for all Shop tabs (facilities, perks, farm).
/// Maps from: ui/screens/shop_screen.py
import Foundation

@MainActor @Observable
final class ShopViewModel {

    let gameState: GameState

    // MARK: - Alert State (shared across tabs)

    var alertMessage = ""
    var showingAlert = false
    var showingBiomePicker = false

    init(gameState: GameState) {
        self.gameState = gameState
    }

    // MARK: - Facilities

    var facilityItems: [ShopItem] {
        Shop.getShopItems(category: .facilities, farmTier: gameState.farmTier)
    }

    var facilityItemsByTier: [(tier: Int, items: [ShopItem])] {
        Dictionary(grouping: facilityItems, by: \.requiredTier)
            .sorted { $0.key < $1.key }
            .map { (tier: $0.key, items: $0.value) }
    }

    func purchaseFacility(_ item: ShopItem) {
        guard let facilityType = item.facilityType else { return }
        let position = Shop.findPlacementPosition(for: facilityType, in: gameState)
        guard position != nil else {
            showError(
                "No space available for \(item.name). Try selling or moving other facilities."
            )
            HapticManager.error()
            return
        }
        if Shop.purchaseItem(state: gameState, item: item, position: position) {
            HapticManager.purchase()
        } else {
            showError("Could not purchase \(item.name).")
            HapticManager.error()
        }
    }

    // MARK: - Perks

    var perksByCategory: [(String, [UpgradeDefinition])] {
        let available = Shop.getAvailablePerks(farmTier: gameState.farmTier)
            .filter(\.implemented)
        let grouped = Dictionary(grouping: available, by: \.category)
        return grouped.sorted { $0.key < $1.key }
    }

    func isPerkOwned(_ perkID: String) -> Bool {
        gameState.purchasedUpgrades.contains(perkID)
    }

    func purchasePerk(_ perk: UpgradeDefinition) {
        if Shop.purchasePerk(perkID: perk.id, state: gameState) {
            HapticManager.purchase()
        } else {
            showError("Could not purchase \(perk.name).")
            HapticManager.error()
        }
    }

    // MARK: - Farm Tier

    var nextTier: TierUpgrade? { Shop.getNextTierUpgrade(state: gameState) }

    var tierRequirements: [String: Bool] {
        guard let tier = nextTier else { return [:] }
        return Shop.checkTierRequirements(state: gameState, upgrade: tier)
    }

    var allRequirementsMet: Bool {
        tierRequirements.values.allSatisfy { $0 }
    }

    var roomInfo: RoomUpgradeInfo? {
        Shop.getFarmUpgradeInfo(state: gameState)
    }

    func upgradeTier() {
        if Shop.purchaseTierUpgrade(state: gameState) {
            HapticManager.purchase()
        } else {
            showError("Farm tier upgrade failed. Check requirements.")
            HapticManager.error()
        }
    }

    func purchaseRoom(biome: BiomeType) {
        if Shop.purchaseNewRoom(state: gameState, biome: biome) {
            HapticManager.purchase()
        } else {
            showError("Room purchase failed. Check your funds.")
            HapticManager.error()
        }
    }

    // MARK: - Alert

    func showError(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}
