// ShopView — 4-tab shop interface for purchasing facilities and items.
// Maps from: ui/screens/shop_screen.py
import SwiftUI

// MARK: - ShopTab

/// The four tabs available in the shop.
enum ShopTab: String, CaseIterable, Sendable {
    case facilities = "Facilities"
    case perks = "Perks"
    case farm = "Farm"
    case pigs = "Pigs"
}

// MARK: - ShopView

/// The main shop view with tabs for facilities, perks, farm upgrades, and pig adoption.
struct ShopView: View {
    let gameState: GameState
    @State private var selectedTab: ShopTab = .facilities
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                FacilitiesTab(gameState: gameState)
                    .tabItem { Label("Facilities", systemImage: "square.grid.2x2") }
                    .tag(ShopTab.facilities)
                PerksTab(gameState: gameState)
                    .tabItem { Label("Perks", systemImage: "star.fill") }
                    .tag(ShopTab.perks)
                FarmTab(gameState: gameState)
                    .tabItem { Label("Farm", systemImage: "arrow.up.circle.fill") }
                    .tag(ShopTab.farm)
                PigsTab(gameState: gameState)
                    .tabItem { Label("Pigs", systemImage: "pawprint.fill") }
                    .tag(ShopTab.pigs)
            }
            .navigationTitle(selectedTab.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    CurrencyLabel(amount: gameState.money)
                }
            }
        }
    }
}

// MARK: - FacilitiesTab

/// Shop tab listing all 17 purchasable facility types, sorted by tier.
private struct FacilitiesTab: View {
    let gameState: GameState
    @State private var alertMessage: String = ""
    @State private var showingAlert = false

    private var items: [ShopItem] {
        Shop.getShopItems(category: .facilities, farmTier: gameState.farmTier)
    }

    var body: some View {
        List {
            ForEach(items, id: \.id) { item in
                FacilityRow(item: item, gameState: gameState, onError: showError)
            }
        }
        .listStyle(.plain)
        .alert("Purchase Failed", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func showError(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}

// MARK: - FacilityRow

/// A single row in the Facilities tab, showing item info and a purchase button.
private struct FacilityRow: View {
    let item: ShopItem
    let gameState: GameState
    let onError: (String) -> Void

    private var canAfford: Bool { gameState.money >= item.cost }
    private var isLocked: Bool { !item.unlocked }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.body.bold())
                        .foregroundStyle(isLocked ? .secondary : .primary)
                    if isLocked {
                        Text("Tier \(item.requiredTier)")
                            .font(.caption2.bold())
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .foregroundStyle(.white)
                            .background(.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                Text(item.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let facilityType = item.facilityType {
                    FacilityBonusLabel(facilityType: facilityType)
                }
            }
            Spacer()
            VStack(spacing: 6) {
                CurrencyLabel(amount: item.cost)
                    .foregroundStyle(canAfford && !isLocked ? .yellow : .secondary)
                Button(action: purchase) {
                    Text(isLocked ? "Locked" : "Buy")
                        .font(.caption.bold())
                        .frame(width: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(isLocked ? .gray : .accentColor)
                .disabled(isLocked || !canAfford)
                .accessibilityLabel(isLocked
                    ? "Locked until Tier \(item.requiredTier)"
                    : "Buy \(item.name) for \(Currency.formatCurrency(item.cost))")
            }
        }
        .padding(.vertical, 4)
        .opacity(isLocked ? 0.6 : 1.0)
    }

    @MainActor
    private func purchase() {
        guard let facilityType = item.facilityType else { return }
        let position = Shop.findPlacementPosition(for: facilityType, in: gameState)
        guard position != nil else {
            onError("No space available for \(item.name). Try selling or moving other facilities.")
            HapticManager.error()
            return
        }
        if Shop.purchaseItem(state: gameState, item: item, position: position) {
            HapticManager.purchase()
        } else {
            onError("Could not purchase \(item.name).")
            HapticManager.error()
        }
    }
}

// MARK: - Preview

private struct ShopPreview: View {
    private let state: GameState = {
        let previewState = GameState()
        previewState.farm = FarmGrid.createStarter()
        previewState.money = 5000
        previewState.farmTier = 2
        return previewState
    }()

    var body: some View {
        ShopView(gameState: state)
    }
}

#Preview {
    ShopPreview()
}
