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
    @State var viewModel: ShopViewModel
    @State private var selectedTab: ShopTab
    @Environment(\.dismiss) private var dismiss

    init(gameState: GameState, initialTab: ShopTab = .facilities) {
        _viewModel = State(initialValue: ShopViewModel(gameState: gameState))
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            Group {
                switch selectedTab {
                case .facilities: FacilitiesTab(viewModel: viewModel)
                case .perks: PerksTab(viewModel: viewModel)
                case .farm: FarmTab(viewModel: viewModel)
                case .pigs: PigsTab(gameState: viewModel.gameState)
                }
            }
            .navigationTitle("Shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Shop section", selection: $selectedTab) {
                        ForEach(ShopTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    CurrencyLabel(amount: viewModel.gameState.money)
                }
            }
            .alert("Purchase Failed", isPresented: $viewModel.showingAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.alertMessage)
            }
        }
    }
}

// MARK: - FacilitiesTab

/// Shop tab listing all 17 purchasable facility types, sorted by tier.
struct FacilitiesTab: View {
    let viewModel: ShopViewModel

    var body: some View {
        List {
            ForEach(viewModel.facilityItemsByTier, id: \.tier) { group in
                Section("Tier \(group.tier)") {
                    ForEach(group.items, id: \.id) { item in
                        FacilityRow(item: item, viewModel: viewModel)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - FacilityRow

/// A single row in the Facilities tab, showing item info and a purchase button.
private struct FacilityRow: View {
    let item: ShopItem
    let viewModel: ShopViewModel

    private var canAfford: Bool { viewModel.gameState.money >= item.cost }
    private var isLocked: Bool { !item.unlocked }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.body.bold())
                    .foregroundStyle(isLocked ? .secondary : .primary)
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
                Button {
                    viewModel.purchaseFacility(item)
                } label: {
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
