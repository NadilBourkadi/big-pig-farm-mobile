# Spec 07 -- SwiftUI Screens

> **Status:** Complete
> **Date:** 2026-02-27
> **Depends on:** 02 (Data Models), 04 (Game Engine)
> **Blocks:** 08 (Persistence & Polish)

---

## 1. Overview

This document specifies every SwiftUI screen and reusable component for the iOS port: the `StatusBarView` HUD overlay, the `ShopView` 4-tab shop, the `PigListView` sortable list, the `PigDetailView` stats panel, the `BreedingView` pair selection and breeding program config, the `AlmanacView` Pigdex/Contracts/Log journal, the `BiomeSelectView` modal picker, the `AdoptionView` bloodline adoption, shared components (`CurrencyLabel`, `NeedBar`, `RarityBadge`, etc.), and the `ContentView` updates that wire these screens into the `.sheet` modifiers defined in Doc 06.

The Python source uses Textual `Screen` subclasses with ASCII/Unicode rendering. The iOS port replaces these with SwiftUI `View` structs presented as `.sheet` overlays on top of the SpriteKit farm scene. All views read directly from `GameState` (`@Observable`) -- no separate view models are needed because `@Observable` provides automatic SwiftUI invalidation.

### Scope

**In scope:**
- `StatusBarView` -- HUD overlay with currency, population, game time, speed, resource levels, and toolbar buttons
- `ShopView` -- 4-tab shop (Facilities, Perks, Upgrades, Adoption) with purchase flow and tier gating
- `PigListView` -- sortable pig list with row selection and embedded detail panel
- `PigDetailView` -- portrait, needs bars, genetics, family, breeding, and AI state for one pig
- `BreedingView` -- breeding program config panel and manual pair selection with offspring prediction
- `AlmanacView` -- 3-tab journal: Pigdex collection grid, contracts, event log
- `BiomeSelectView` -- modal sheet for selecting biome when adding a new room
- `AdoptionView` -- bloodline pig browser (also embedded as the Adoption tab of ShopView)
- Shared components: `CurrencyLabel`, `NeedBar`, `RarityBadge`, `BreedingStatusLabel`, `FacilityBonusLabel`, `PigPortraitView`, `ConfirmationDialog` helper
- `ContentView` updates -- completing the `.sheet` wiring and `FarmSceneCoordinator` delegate stubs from Doc 06

**Out of scope:**
- Farm scene rendering (Doc 06)
- Game engine, tick loop, simulation logic (Doc 04)
- Behavior AI (Doc 05)
- Sprite pipeline and asset catalog (Doc 03)
- Save/load persistence (Doc 08)
- App icon, launch screen (Doc 08)

### Deliverable Summary

| Category | Files | Estimated Lines |
|----------|-------|----------------|
| StatusBarView | `Views/StatusBarView.swift` | ~200 |
| ShopView | `Views/ShopView.swift` | ~280 |
| PigListView | `Views/PigListView.swift` | ~200 |
| PigDetailView | `Views/PigDetailView.swift` | ~280 |
| BreedingView | `Views/BreedingView.swift` | ~300 |
| AlmanacView | `Views/AlmanacView.swift` | ~280 |
| BiomeSelectView | `Views/BiomeSelectView.swift` | ~150 |
| AdoptionView | `Views/AdoptionView.swift` | ~180 |
| SharedComponents | `Views/SharedComponents.swift` | ~200 |
| ContentView updates | `ContentView.swift` | ~60 delta |
| Tests | `BigPigFarmTests/SwiftUIScreensTests.swift` | ~200 |
| **Total** | **11 files** | **~2,330** |

### Source File Mapping

| Python Source | Lines | Swift Target | Notes |
|---------------|-------|-------------|-------|
| `ui/widgets/status_bar.py` | 128 | `Views/StatusBarView.swift` | Textual `Static` widget becomes SwiftUI overlay |
| `ui/screens/shop.py` | 753 | `Views/ShopView.swift` | 4 Textual `ListView` tabs become SwiftUI `TabView` with `List` |
| `ui/screens/pig_list.py` | 229 | `Views/PigListView.swift` | Textual `DataTable` becomes SwiftUI `List` |
| `ui/screens/pig_detail.py` | 302 | `Views/PigDetailView.swift` | `PigDetailPanel` + `PigDetailScreen` merge into one `View` |
| `ui/widgets/pig_sidebar.py` | 173 | `Views/PigDetailView.swift` | Sidebar content folds into `PigDetailView` |
| `ui/screens/breeding.py` | 571 | `Views/BreedingView.swift` | `TabbedContent` becomes `TabView` |
| `ui/widgets/breeding_program_panel.py` | 280 | `Views/BreedingView.swift` | Integrated as a section within `BreedingView` |
| `ui/screens/almanac.py` | 310 | `Views/AlmanacView.swift` | 3-tab journal |
| `ui/screens/biome_select.py` | 179 | `Views/BiomeSelectView.swift` | Textual `ModalScreen` becomes SwiftUI `.sheet` |
| `ui/screens/adoption.py` | 73 | `Views/AdoptionView.swift` | Adoption logic + shop tab integration |
| `ui/screens/confirm.py` | 69 | SwiftUI `.confirmationDialog` | No custom screen needed |
| `ui/utils.py` | 73 | `Views/SharedComponents.swift` | Formatting helpers become SwiftUI components |

---

## 2. Navigation Architecture

### Sheet-Based Navigation

Per ROADMAP Decision 5, `SpriteView` is the root view and all menu screens are presented as `.sheet` overlays. This is the simplest SpriteKit/SwiftUI bridge -- no UIKit hosting controllers, no `NavigationStack` for the top-level flow.

**Maps from:** `main_game.py` `MainGameScreen` -- `push_screen(ShopScreen(...))` calls become SwiftUI `showShop = true` state toggles that trigger `.sheet(isPresented:)` modifiers.

### Sheet Presentation State

`ContentView` (specified in Doc 06 Section 11) owns boolean `@State` properties for each presentable screen:

```swift
@State private var showShop = false
@State private var showPigList = false
@State private var showBreeding = false
@State private var showAlmanac = false
@State private var showPigDetail = false
@State private var selectedPigID: UUID?
```

Each `.sheet` modifier receives `gameState` and any required parameters:

```swift
.sheet(isPresented: $showShop) {
    ShopView(gameState: gameState)
}
.sheet(isPresented: $showPigList) {
    PigListView(gameState: gameState, onFollowPig: handleFollowPig)
}
```

### In-Sheet Navigation

Within a sheet, deeper navigation uses `NavigationStack`:

- **ShopView**: Tapping "Add Room" in the Upgrades tab pushes `BiomeSelectView` inside the sheet
- **PigListView**: Tapping a row shows `PigDetailView` inline (split view) or navigates to it on compact widths
- **BreedingView**: Tab switching between Program and Pair tabs uses `TabView` within the sheet

### Confirmation Dialogs

The Python `ConfirmScreen` modal is replaced by SwiftUI's `.confirmationDialog` modifier. No custom view is needed:

```swift
.confirmationDialog(
    "Sell \(pig.name)?",
    isPresented: $showSellConfirmation,
    titleVisibility: .visible
) {
    Button("Sell for \(Currency.format(value))", role: .destructive) {
        sellPig(pig)
    }
    Button("Cancel", role: .cancel) {}
}
```

### Sheet Lifecycle

When a `.sheet` is presented:
- The simulation continues running (the `GameEngine` timer on the main run loop is not paused)
- `GameState` is `@Observable`, so the sheet view automatically reflects live state updates
- Dismissing the sheet returns to the farm scene, which has been updating in the background

**Decision:** The simulation does NOT pause when a sheet opens. This matches the Python behavior where `push_screen` overlays a screen but the game tick loop continues underneath. If playtesting reveals this is confusing (pigs moving while the player is in the shop), add an optional auto-pause setting in Doc 08.

---

## 3. StatusBarView (HUD Overlay)

**Maps from:** `ui/widgets/status_bar.py` (128 lines) -- `StatusBar` Textual widget that displays a single-line bar with game state info and a 10Hz refresh timer.

**Swift file:** `BigPigFarm/Views/StatusBarView.swift`

### Architecture

`StatusBarView` is a semi-transparent overlay anchored to the top of the screen, above the SpriteKit farm scene. Unlike the Python version (which is a Textual widget owned by the screen), the SwiftUI version is a child of `ContentView`'s `ZStack`, floating over the `SpriteView`.

It reads directly from `GameState` via `@Observable`. No separate timer is needed -- SwiftUI automatically re-renders when observed properties change.

The status bar has two rows:
1. **Info row**: Day, tier, currency, pig count, food/water levels, speed indicator
2. **Button row**: Toolbar icons to open screens (Shop, Pigs, Breed, Almanac, Edit, Pause/Speed)

### Type Signature

```swift
import SwiftUI

/// HUD overlay displayed above the farm scene.
///
/// Maps from: ui/widgets/status_bar.py (StatusBar class)
///
/// Shows game state at a glance (currency, population, resources, time)
/// and provides toolbar buttons to open menu screens.
struct StatusBarView: View {
    /// The game state to display. @Observable provides automatic updates.
    let gameState: GameState

    /// Whether edit mode is active (bound to ContentView state).
    @Binding var isEditMode: Bool

    // MARK: - Action Callbacks

    /// Called when the player taps the Shop button.
    var onShopTapped: () -> Void

    /// Called when the player taps the Pigs button.
    var onPigListTapped: () -> Void

    /// Called when the player taps the Breed button.
    var onBreedingTapped: () -> Void

    /// Called when the player taps the Almanac button.
    var onAlmanacTapped: () -> Void

    /// Called when the player taps the Edit button.
    var onEditTapped: () -> Void

    /// Called when the player taps the Pause button.
    var onPauseTapped: () -> Void

    /// Called when the player taps the Speed button.
    var onSpeedTapped: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            infoRow
            buttonRow
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
    }
}
```

### Info Row

```swift
extension StatusBarView {
    /// Top row: Day, tier, currency, pigs, food, water, speed.
    private var infoRow: some View {
        HStack(spacing: 12) {
            // Day counter
            Text("Day \(gameState.gameTime.day)")
                .font(.caption.bold())

            // Farm tier
            Text("T\(gameState.farmTier)")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Currency
            CurrencyLabel(amount: gameState.money)

            // Population
            Text("\(gameState.pigCount)/\(gameState.capacity)")
                .font(.caption)

            Spacer()

            // Food level
            resourceIndicator(
                systemImage: "fork.knife",
                level: foodLevel,
                warningThreshold: 30
            )

            // Water level
            resourceIndicator(
                systemImage: "drop.fill",
                level: waterLevel,
                warningThreshold: 30
            )

            // Speed indicator
            speedIndicator
        }
        .font(.caption)
    }
}
```

### Resource Level Computation

The Python `StatusBar` recomputes food/water levels every 10 frames (~1 second at 10 Hz). In SwiftUI, we compute these as properties that read from `GameState`. Since `@Observable` only triggers re-render when accessed properties change, and facility amounts change every tick, we throttle by reading from a cached value.

```swift
extension StatusBarView {
    /// Average food level across all food-type facilities (0-100).
    ///
    /// Maps from: status_bar.py _recompute_facility_levels()
    private var foodLevel: Int {
        let foodFacilities = gameState.getFacilitiesByType(.foodBowl)
            + gameState.getFacilitiesByType(.hayRack)
        guard !foodFacilities.isEmpty else { return 0 }
        let avg = foodFacilities.reduce(0.0) { $0 + $1.fillPercentage }
            / Double(foodFacilities.count)
        return Int(avg)
    }

    /// Average water level across all water facilities (0-100).
    private var waterLevel: Int {
        let waterFacilities = gameState.getFacilitiesByType(.waterBottle)
        guard !waterFacilities.isEmpty else { return 0 }
        let avg = waterFacilities.reduce(0.0) { $0 + $1.fillPercentage }
            / Double(waterFacilities.count)
        return Int(avg)
    }
}
```

### Speed Indicator

```swift
extension StatusBarView {
    /// Displays pause/play/fast-forward state.
    ///
    /// Maps from: status_bar.py render() speed_str logic.
    @ViewBuilder
    private var speedIndicator: some View {
        if gameState.isPaused {
            Image(systemName: "pause.fill")
                .foregroundStyle(.yellow)
        } else {
            let speedLabel = GameConfig.Speed.displayName(for: gameState.speed)
            Text(speedLabel)
                .font(.caption2)
        }
    }
}
```

### Button Row

```swift
extension StatusBarView {
    /// Bottom row: toolbar buttons for opening screens.
    private var buttonRow: some View {
        HStack(spacing: 16) {
            toolbarButton(systemImage: "cart.fill", label: "Shop",
                          action: onShopTapped)
            toolbarButton(systemImage: "list.bullet", label: "Pigs",
                          action: onPigListTapped)
            toolbarButton(systemImage: "heart.fill", label: "Breed",
                          action: onBreedingTapped)
            toolbarButton(systemImage: "book.fill", label: "Almanac",
                          action: onAlmanacTapped)

            Spacer()

            // Edit mode toggle
            toolbarButton(
                systemImage: isEditMode ? "pencil.slash" : "pencil",
                label: "Edit",
                action: onEditTapped,
                isActive: isEditMode
            )

            // Pause/Resume
            toolbarButton(
                systemImage: gameState.isPaused ? "play.fill" : "pause.fill",
                label: gameState.isPaused ? "Play" : "Pause",
                action: onPauseTapped
            )

            // Speed cycle
            toolbarButton(
                systemImage: "forward.fill",
                label: "Speed",
                action: onSpeedTapped
            )
        }
    }

    /// A single toolbar button with icon and label.
    private func toolbarButton(
        systemImage: String,
        label: String,
        action: @escaping () -> Void,
        isActive: Bool = false
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 9))
            }
            .foregroundStyle(isActive ? .yellow : .white)
        }
        .buttonStyle(.plain)
    }

    /// A resource indicator with icon and percentage.
    private func resourceIndicator(
        systemImage: String,
        level: Int,
        warningThreshold: Int
    ) -> some View {
        HStack(spacing: 2) {
            Image(systemName: systemImage)
                .font(.system(size: 10))
            Text("\(level)%")
                .font(.caption2)
        }
        .foregroundStyle(level < warningThreshold ? .red : .primary)
    }
}
```

### Population Warning

The Python `StatusBar` shows "LOW POP" when the breeding program is enabled and the adult count is at or below `MIN_BREEDING_POPULATION`. The SwiftUI version adds a warning badge to the info row.

```swift
extension StatusBarView {
    /// Whether the low-population warning should be shown.
    ///
    /// Maps from: status_bar.py _recompute_population_warning()
    private var showLowPopulationWarning: Bool {
        guard gameState.breedingProgram.enabled else { return false }
        let adultCount = gameState.getPigsList()
            .filter { !$0.isBaby }.count
        return adultCount <= BreedingConfig.minBreedingPopulation
    }
}
```

---

## 4. ShopView (4-Tab Shop)

**Maps from:** `ui/screens/shop.py` (753 lines) -- `ShopScreen` with 4 categories: Facilities, Perks, Upgrades, Adoption.

**Swift file:** `BigPigFarm/Views/ShopView.swift`

### Architecture

The Python `ShopScreen` uses a `reactive[ShopCategory]` to switch between 4 `ListView` contents, with a detail panel at the bottom. The SwiftUI version uses a `TabView` with 4 tabs, each containing a `List`. A detail section sits below the list in each tab.

### Type Signature

```swift
import SwiftUI

/// The shop screen with 4 tabs: Facilities, Perks, Upgrades, Adoption.
///
/// Maps from: ui/screens/shop.py (ShopScreen class)
///
/// Presented as a .sheet from ContentView. Each tab shows a scrollable
/// list of purchasable items with a detail section for the selected item.
struct ShopView: View {
    /// The game state. @Observable provides live balance updates.
    let gameState: GameState

    /// The currently selected tab.
    @State private var selectedTab: ShopTab = .facilities

    /// Dismiss action to close the sheet.
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                FacilitiesTab(gameState: gameState)
                    .tabItem { Label("Facilities", systemImage: "hammer.fill") }
                    .tag(ShopTab.facilities)

                PerksTab(gameState: gameState)
                    .tabItem { Label("Perks", systemImage: "star.fill") }
                    .tag(ShopTab.perks)

                UpgradesTab(gameState: gameState)
                    .tabItem { Label("Upgrades", systemImage: "arrow.up.circle.fill") }
                    .tag(ShopTab.upgrades)

                AdoptionView(gameState: gameState)
                    .tabItem { Label("Adopt", systemImage: "heart.circle.fill") }
                    .tag(ShopTab.adoption)
            }
            .navigationTitle("Shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    CurrencyLabel(amount: gameState.money)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// The 4 shop tabs.
enum ShopTab: String, CaseIterable, Sendable {
    case facilities
    case perks
    case upgrades
    case adoption
}
```

### Facilities Tab

```swift
/// Lists all purchasable facilities, grouped by tier.
///
/// Maps from: shop.py ShopScreen with current_category == FACILITIES.
/// Tier headers separate items by required tier level.
private struct FacilitiesTab: View {
    let gameState: GameState

    /// The facility item currently selected for detail display.
    @State private var selectedItem: ShopItem?

    /// Whether the sell confirmation is showing.
    @State private var showPurchaseError = false
    @State private var purchaseErrorMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedItem) {
                let items = Shop.getShopItems(
                    category: .facilities,
                    farmTier: gameState.farmTier
                )
                let grouped = Dictionary(grouping: items) { $0.requiredTier }
                let sortedTiers = grouped.keys.sorted()

                ForEach(sortedTiers, id: \.self) { tier in
                    Section("Tier \(tier)") {
                        ForEach(grouped[tier] ?? [], id: \.name) { item in
                            FacilityRow(item: item, canAfford: gameState.money >= item.cost)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedItem = item }
                        }
                    }
                }
            }
            .listStyle(.plain)

            // Detail panel
            if let item = selectedItem {
                ShopItemDetail(item: item, gameState: gameState) {
                    purchaseFacility(item)
                }
            }
        }
        .alert("Cannot Purchase", isPresented: $showPurchaseError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchaseErrorMessage)
        }
    }

    /// Attempt to purchase a facility and place it on the farm.
    ///
    /// Maps from: shop.py action_purchase() facility branch.
    private func purchaseFacility(_ item: ShopItem) {
        guard item.unlocked else {
            purchaseErrorMessage = "Requires Tier \(item.requiredTier)"
            showPurchaseError = true
            return
        }
        guard gameState.money >= item.cost else {
            purchaseErrorMessage = "Not enough Squeaks!"
            showPurchaseError = true
            return
        }
        guard let facilityType = item.facilityType else { return }

        guard let position = Shop.findPlacementPosition(
            for: facilityType, in: gameState
        ) else {
            purchaseErrorMessage = "No space for this facility!"
            showPurchaseError = true
            return
        }

        _ = Shop.purchaseItem(item, at: position, state: gameState)
    }
}
```

### Facility Row

```swift
/// A single row in the facilities list.
private struct FacilityRow: View {
    let item: ShopItem
    let canAfford: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.name)
                    .font(.body)
                    .foregroundStyle(item.unlocked ? .primary : .secondary)
                if !item.unlocked {
                    Text("Tier \(item.requiredTier)")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            Spacer()
            CurrencyLabel(amount: item.cost)
                .foregroundStyle(canAfford ? .primary : .red)
        }
        .opacity(item.unlocked ? 1.0 : 0.5)
    }
}
```

### Shop Item Detail

```swift
/// Detail panel shown below the list for the selected shop item.
///
/// Maps from: shop.py _update_detail() for facility/item branch.
private struct ShopItemDetail: View {
    let item: ShopItem
    let gameState: GameState
    let onPurchase: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.name).font(.headline)
                Spacer()
                CurrencyLabel(amount: item.cost)
            }
            Text(item.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let facilityType = item.facilityType {
                FacilityBonusLabel(facilityType: facilityType)
            }

            Button("Purchase") { onPurchase() }
                .buttonStyle(.borderedProminent)
                .disabled(gameState.money < item.cost || !item.unlocked)
        }
        .padding()
        .background(.regularMaterial)
    }
}
```

### Perks Tab

```swift
/// Lists all permanent upgrade perks, grouped by tier.
///
/// Maps from: shop.py ShopScreen with current_category == PERKS.
private struct PerksTab: View {
    let gameState: GameState

    @State private var selectedPerk: UpgradeDefinition?
    @State private var showPurchaseError = false
    @State private var purchaseErrorMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            List {
                let perks = Shop.getAvailablePerks(
                    farmTier: gameState.farmTier,
                    purchased: gameState.purchasedUpgrades
                )
                let grouped = Dictionary(grouping: perks) { $0.requiredTier }
                let sortedTiers = grouped.keys.sorted()

                ForEach(sortedTiers, id: \.self) { tier in
                    Section("Tier \(tier)") {
                        ForEach(grouped[tier] ?? [], id: \.id) { perk in
                            PerkRow(
                                perk: perk,
                                purchased: gameState.purchasedUpgrades.contains(perk.id),
                                canAfford: gameState.money >= perk.cost
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { selectedPerk = perk }
                        }
                    }
                }
            }
            .listStyle(.plain)

            if let perk = selectedPerk {
                PerkDetail(
                    perk: perk,
                    purchased: gameState.purchasedUpgrades.contains(perk.id),
                    gameState: gameState
                ) {
                    purchasePerk(perk)
                }
            }
        }
        .alert("Cannot Purchase", isPresented: $showPurchaseError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchaseErrorMessage)
        }
    }

    /// Attempt to purchase a perk.
    ///
    /// Maps from: shop.py _purchase_perk()
    private func purchasePerk(_ perk: UpgradeDefinition) {
        guard gameState.money >= perk.cost else {
            purchaseErrorMessage = "Not enough Squeaks!"
            showPurchaseError = true
            return
        }
        guard !gameState.purchasedUpgrades.contains(perk.id) else {
            purchaseErrorMessage = "Already owned!"
            showPurchaseError = true
            return
        }
        _ = Shop.purchasePerk(perkID: perk.id, state: gameState)
    }
}

/// A single row for a perk.
private struct PerkRow: View {
    let perk: UpgradeDefinition
    let purchased: Bool
    let canAfford: Bool

    var body: some View {
        HStack {
            Image(systemName: purchased ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(purchased ? .green : .secondary)
            VStack(alignment: .leading) {
                Text(perk.name)
                    .font(.body)
                    .foregroundStyle(purchased ? .secondary : .primary)
                Text(perk.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if !purchased {
                CurrencyLabel(amount: perk.cost)
                    .foregroundStyle(canAfford ? .primary : .red)
            } else {
                Text("Owned")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .opacity(purchased ? 0.6 : 1.0)
    }
}

/// Detail panel for a selected perk.
private struct PerkDetail: View {
    let perk: UpgradeDefinition
    let purchased: Bool
    let gameState: GameState
    let onPurchase: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(perk.name).font(.headline)
                Spacer()
                if purchased {
                    Text("OWNED").font(.caption).foregroundStyle(.green)
                } else {
                    CurrencyLabel(amount: perk.cost)
                }
            }
            Text(perk.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            if !purchased {
                Button("Purchase") { onPurchase() }
                    .buttonStyle(.borderedProminent)
                    .disabled(gameState.money < perk.cost)
            }
        }
        .padding()
        .background(.regularMaterial)
    }
}
```

### Upgrades Tab

```swift
/// Shows tier upgrades and room additions.
///
/// Maps from: shop.py ShopScreen with current_category == UPGRADES.
private struct UpgradesTab: View {
    let gameState: GameState

    @State private var showBiomeSelect = false
    @State private var showPurchaseError = false
    @State private var purchaseErrorMessage = ""

    var body: some View {
        List {
            // Tier upgrade section
            Section("Farm Tier") {
                tierUpgradeRow
            }

            // Room addition section
            Section("Rooms") {
                roomAdditionRow
            }
        }
        .listStyle(.insetGrouped)
        .sheet(isPresented: $showBiomeSelect) {
            BiomeSelectView(
                farmTier: gameState.farmTier,
                existingBiomes: Set(gameState.farm.areas.map(\.biome)),
                onBiomeSelected: handleBiomeSelected
            )
        }
        .alert("Cannot Purchase", isPresented: $showPurchaseError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchaseErrorMessage)
        }
    }

    /// Tier upgrade row showing current tier and next upgrade.
    ///
    /// Maps from: shop.py _refresh_items() UPGRADES branch, tier-upgrade item.
    @ViewBuilder
    private var tierUpgradeRow: some View {
        if let nextTier = Shop.getNextTierUpgrade(state: gameState) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Tier \(nextTier.tier): \(nextTier.name)")
                        .font(.body)
                    Spacer()
                    CurrencyLabel(amount: nextTier.cost)
                }
                Text("Unlocks tier \(nextTier.tier) items, up to \(nextTier.maxRooms) rooms")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Requirements
                let reqs = Shop.checkTierRequirements(state: gameState, tier: nextTier)
                ForEach(Array(reqs.keys.sorted()), id: \.self) { key in
                    HStack(spacing: 4) {
                        Image(systemName: reqs[key] == true
                              ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(reqs[key] == true ? .green : .red)
                            .font(.caption)
                        Text(key.capitalized)
                            .font(.caption)
                    }
                }

                Button("Upgrade") { purchaseTierUpgrade(nextTier) }
                    .buttonStyle(.borderedProminent)
                    .disabled(!reqs.values.allSatisfy { $0 })
            }
        } else {
            Text("Max tier reached!")
                .foregroundStyle(.secondary)
        }
    }

    /// Room addition row.
    ///
    /// Maps from: shop.py _refresh_items() UPGRADES branch, farm-upgrade item.
    @ViewBuilder
    private var roomAdditionRow: some View {
        let upgradeInfo = Shop.getFarmUpgradeInfo(state: gameState)
        if upgradeInfo != nil {
            VStack(alignment: .leading, spacing: 4) {
                Text("Add New Room")
                    .font(.body)
                Text("Rooms: \(gameState.farm.areas.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Choose Biome") { showBiomeSelect = true }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            let rooms = gameState.farm.areas.count
            Text("All rooms built (\(rooms))")
                .foregroundStyle(.secondary)
        }
    }

    /// Purchase tier upgrade.
    ///
    /// Maps from: shop.py action_purchase() tier-upgrade branch.
    private func purchaseTierUpgrade(_ tier: TierUpgrade) {
        let reqs = Shop.checkTierRequirements(state: gameState, tier: tier)
        guard reqs.values.allSatisfy({ $0 }) else {
            purchaseErrorMessage = "Requirements not met"
            showPurchaseError = true
            return
        }
        _ = Shop.purchaseTierUpgrade(state: gameState)
    }

    /// Handle biome selection callback.
    ///
    /// Maps from: shop.py _on_biome_selected()
    private func handleBiomeSelected(_ biome: BiomeType?) {
        guard let biome else { return }
        let totalCost = Shop.getRoomTotalCost(state: gameState, biome: biome)
        guard gameState.money >= totalCost else {
            purchaseErrorMessage = "Need \(Currency.format(totalCost))!"
            showPurchaseError = true
            return
        }
        _ = Shop.purchaseNewRoom(state: gameState, biome: biome)
    }
}
```

---

## 5. PigListView (Sortable List)

**Maps from:** `ui/screens/pig_list.py` (229 lines) -- `PigListScreen` with `DataTable`, row navigation, sell/follow/lock actions.

**Swift file:** `BigPigFarm/Views/PigListView.swift`

### Architecture

The Python version uses a `DataTable` (terminal table widget) with 7 columns. The SwiftUI version uses a `List` with custom row views. Sorting is done via `@State` sort descriptors. The detail panel is shown inline when a pig is selected.

### Type Signature

```swift
import SwiftUI

/// Displays all guinea pigs in a sortable list with a split detail panel.
///
/// Maps from: ui/screens/pig_list.py (PigListScreen class)
///
/// Presented as a .sheet from ContentView. Tapping a row shows the pig's
/// detail view. Actions: Follow (return to farm centered on pig), Sell,
/// Lock breeding.
struct PigListView: View {
    /// The game state. @Observable provides live pig data.
    let gameState: GameState

    /// Callback to follow a pig on the farm (dismisses the sheet and
    /// centers the camera on the pig).
    var onFollowPig: ((UUID) -> Void)?

    /// The currently selected pig ID.
    @State private var selectedPigID: UUID?

    /// The current sort criterion.
    @State private var sortBy: PigSortCriterion = .name

    /// Whether sort is ascending.
    @State private var sortAscending = true

    /// Whether the sell confirmation dialog is showing.
    @State private var showSellConfirmation = false

    /// The pig being considered for sale.
    @State private var pigToSell: UUID?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                // Pig list (left panel)
                pigList
                    .frame(minWidth: 250)

                // Detail panel (right side, when a pig is selected)
                if let pigID = selectedPigID,
                   let pig = gameState.getGuineaPig(pigID) {
                    Divider()
                    PigDetailView(gameState: gameState, pig: pig)
                        .frame(width: 300)
                }
            }
            .navigationTitle("Guinea Pigs (\(gameState.pigCount)/\(gameState.capacity))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    sortMenu
                }
            }
        }
        .confirmationDialog(
            sellConfirmationTitle,
            isPresented: $showSellConfirmation,
            titleVisibility: .visible
        ) {
            if let pigID = pigToSell, let pig = gameState.getGuineaPig(pigID) {
                let value = Market.calculatePigValue(pig, state: gameState)
                Button("Sell for \(Currency.format(value))", role: .destructive) {
                    sellPig(pigID)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
```

### Sort Criteria

```swift
/// Available sort criteria for the pig list.
///
/// Maps from: pig_list.py DataTable columns (Name, Age, Gender, Color,
/// Happiness, Breed, Value).
enum PigSortCriterion: String, CaseIterable, Sendable {
    case name = "Name"
    case age = "Age"
    case gender = "Gender"
    case color = "Color"
    case happiness = "Happiness"
    case value = "Value"
    case rarity = "Rarity"
}
```

### Pig List Body

```swift
extension PigListView {
    /// The scrollable list of pig rows.
    private var pigList: some View {
        List(sortedPigs, id: \.id, selection: $selectedPigID) { pig in
            PigRow(pig: pig, gameState: gameState)
                .contentShape(Rectangle())
                .swipeActions(edge: .trailing) {
                    Button("Sell", role: .destructive) {
                        pigToSell = pig.id
                        showSellConfirmation = true
                    }
                    Button("Follow") {
                        onFollowPig?(pig.id)
                        dismiss()
                    }
                    .tint(.blue)
                }
                .swipeActions(edge: .leading) {
                    Button(pig.breedingLocked ? "Unlock" : "Lock") {
                        toggleBreedingLock(pig.id)
                    }
                    .tint(pig.breedingLocked ? .green : .orange)
                }
        }
        .listStyle(.plain)
    }

    /// Pigs sorted by the current sort criterion.
    ///
    /// Maps from: pig_list.py _refresh_table() which sorts by DataTable columns.
    private var sortedPigs: [GuineaPig] {
        let pigs = gameState.getPigsList()
        let sorted: [GuineaPig]
        switch sortBy {
        case .name:
            sorted = pigs.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .age:
            sorted = pigs.sorted { $0.ageDays < $1.ageDays }
        case .gender:
            sorted = pigs.sorted { $0.gender.rawValue < $1.gender.rawValue }
        case .color:
            sorted = pigs.sorted { $0.phenotype.displayName < $1.phenotype.displayName }
        case .happiness:
            sorted = pigs.sorted { $0.needs.happiness > $1.needs.happiness }
        case .value:
            sorted = pigs.sorted {
                Market.calculatePigValue($0, state: gameState)
                    > Market.calculatePigValue($1, state: gameState)
            }
        case .rarity:
            sorted = pigs.sorted {
                $0.phenotype.rarity.sortOrder > $1.phenotype.rarity.sortOrder
            }
        }
        return sortAscending ? sorted : sorted.reversed()
    }

    /// Sort menu for the toolbar.
    private var sortMenu: some View {
        Menu {
            ForEach(PigSortCriterion.allCases, id: \.self) { criterion in
                Button {
                    if sortBy == criterion {
                        sortAscending.toggle()
                    } else {
                        sortBy = criterion
                        sortAscending = true
                    }
                } label: {
                    HStack {
                        Text(criterion.rawValue)
                        if sortBy == criterion {
                            Image(systemName: sortAscending
                                  ? "chevron.up" : "chevron.down")
                        }
                    }
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
    }
}
```

### Pig Row

```swift
/// A single row in the pig list.
///
/// Maps from: pig_list.py _refresh_table() row content.
private struct PigRow: View {
    let pig: GuineaPig
    let gameState: GameState

    var body: some View {
        HStack {
            // Color indicator dot
            Circle()
                .fill(pigColorSwiftUI(pig.phenotype.baseColor))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(pig.name)
                        .font(.body.bold())
                    RarityBadge(rarity: pig.phenotype.rarity)
                }
                HStack(spacing: 8) {
                    Text(pig.phenotype.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Int(pig.ageDays))d")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(pig.gender.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                NeedBar(value: pig.needs.happiness / 100.0, label: "")
                    .frame(width: 60)
                BreedingStatusLabel(pig: pig)
            }
        }
        .padding(.vertical, 2)
    }
}
```

### Sell and Lock Actions

```swift
extension PigListView {
    /// Sell the specified pig.
    ///
    /// Maps from: pig_list.py action_sell_pig()
    private func sellPig(_ pigID: UUID) {
        guard let pig = gameState.getGuineaPig(pigID) else { return }
        let result = Market.sellPig(pig, state: gameState)
        // Market.sellPig handles removing the pig, adding money, and logging
        _ = result
        selectedPigID = nil
    }

    /// Toggle breeding lock on a pig.
    ///
    /// Maps from: pig_list.py action_toggle_breeding_lock()
    private func toggleBreedingLock(_ pigID: UUID) {
        guard var pig = gameState.getGuineaPig(pigID) else { return }
        pig.breedingLocked.toggle()
        gameState.guineaPigs[pigID] = pig
    }

    /// Title for the sell confirmation dialog.
    private var sellConfirmationTitle: String {
        guard let pigID = pigToSell,
              let pig = gameState.getGuineaPig(pigID) else {
            return "Sell pig?"
        }
        let value = Market.calculatePigValue(pig, state: gameState)
        return "Sell \(pig.name) for \(Currency.format(value))?"
    }
}
```

---

## 6. PigDetailView (Stats + Genetics)

**Maps from:** `ui/screens/pig_detail.py` (302 lines) -- `PigDetailPanel` embedded widget + `PigDetailScreen` standalone screen. Also `ui/widgets/pig_sidebar.py` (173 lines) -- sidebar content folds into this view.

**Swift file:** `BigPigFarm/Views/PigDetailView.swift`

### Architecture

The Python source has two presentations: `PigDetailPanel` (embedded in pig list split view and sidebar) and `PigDetailScreen` (standalone screen with its own bindings). The SwiftUI version unifies these into a single `PigDetailView` that can be used inline (in `PigListView` split) or presented as a standalone sheet.

### Type Signature

```swift
import SwiftUI

/// Detailed view of a single guinea pig showing portrait, stats, genetics,
/// and family info.
///
/// Maps from: ui/screens/pig_detail.py (PigDetailPanel + PigDetailScreen)
/// Also maps from: ui/widgets/pig_sidebar.py (PigSidebar content)
///
/// Can be embedded inline (PigListView detail panel) or presented standalone
/// via .sheet when tapping a pig on the farm scene.
struct PigDetailView: View {
    /// The game state for live updates and facility lookups.
    let gameState: GameState

    /// The pig to display. Read from GameState on each render for live data.
    let pig: GuineaPig

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                portraitSection
                basicInfoSection
                needsSection
                personalitySection
                breedingSection
                familySection
                geneticsSection
                aiStateSection
                recentActivitySection
            }
            .padding()
        }
    }
}
```

### Header Section

```swift
extension PigDetailView {
    /// Name, gender icon, and phenotype display name.
    ///
    /// Maps from: pig_detail.py _build_content() header lines.
    private var headerSection: some View {
        HStack {
            Text(pig.name)
                .font(.title2.bold())
            Text(pig.gender == .male ? "M" : "F")
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()
            RarityBadge(rarity: pig.phenotype.rarity)
        }
    }
}
```

### Portrait Section

```swift
extension PigDetailView {
    /// Pig portrait image loaded from the asset catalog.
    ///
    /// Maps from: pig_detail.py _build_portrait_text() and
    /// pig_sidebar.py _build_portrait(). The Python version renders
    /// a half-block portrait at runtime. The iOS version uses a
    /// pre-rendered portrait PNG from the sprite pipeline (Doc 03).
    private var portraitSection: some View {
        PigPortraitView(
            baseColor: pig.phenotype.baseColor,
            pattern: pig.phenotype.pattern,
            intensity: pig.phenotype.intensity,
            roan: pig.phenotype.roan,
            pigID: pig.id
        )
        .frame(maxWidth: .infinity)
        .frame(height: 120)
    }
}
```

### Basic Info Section

```swift
extension PigDetailView {
    /// Age, gender, rarity, area, and sale value.
    ///
    /// Maps from: pig_detail.py _build_content() BASIC INFO section.
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Basic Info")

            infoRow("Age", "\(Int(pig.ageDays)) days (\(pig.ageGroup.rawValue))")
            infoRow("Color", pig.phenotype.displayName)

            // Current area
            if let areaID = pig.currentAreaID,
               let area = gameState.farm.getAreaByID(areaID) {
                let biomeInfo = biomes[area.biome]
                infoRow("Area", "\(area.name) (\(biomeInfo?.displayName ?? ""))")
            }

            // Birth area
            if let birthAreaID = pig.birthAreaID,
               let birthArea = gameState.farm.getAreaByID(birthAreaID) {
                let biomeInfo = biomes[birthArea.biome]
                infoRow("Born in", "\(birthArea.name) (\(biomeInfo?.displayName ?? ""))")
            }

            // Preferred biome
            if let preferredBiome = pig.preferredBiome,
               let biomeType = BiomeType(rawValue: preferredBiome),
               let biomeInfo = biomes[biomeType] {
                infoRow("Preferred biome", biomeInfo.displayName)
            }

            // Sale value
            let breakdown = Market.calculatePigValueBreakdown(pig, state: gameState)
            infoRow("Sale Value", Currency.format(breakdown.total))

            if pig.originTag != nil {
                infoRow("Origin", pig.originTag ?? "")
            }
        }
    }
}
```

### Needs Section

```swift
extension PigDetailView {
    /// Seven need bars: hunger, thirst, energy, happiness, health, social, fun.
    ///
    /// Maps from: pig_detail.py _build_content() NEEDS section and
    /// pig_sidebar.py refresh_content() needs bars.
    private var needsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Needs")

            NeedBar(value: pig.needs.hunger / 100.0, label: "Hunger")
            NeedBar(value: pig.needs.thirst / 100.0, label: "Thirst")
            NeedBar(value: pig.needs.energy / 100.0, label: "Energy")
            NeedBar(value: pig.needs.happiness / 100.0, label: "Happiness")
            NeedBar(value: pig.needs.health / 100.0, label: "Health")
            NeedBar(value: pig.needs.social / 100.0, label: "Social")
            NeedBar(value: (100.0 - pig.needs.boredom) / 100.0, label: "Fun")
        }
    }
}
```

### Personality Section

```swift
extension PigDetailView {
    /// Personality trait list.
    ///
    /// Maps from: pig_detail.py _build_content() PERSONALITY section.
    private var personalitySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Personality")
            let traits = pig.personality.map { $0.rawValue.capitalized }
            Text(traits.joined(separator: ", "))
                .font(.body)
        }
    }
}
```

### Breeding Section

```swift
extension PigDetailView {
    /// Breeding status, lock state, auto-sell mark.
    ///
    /// Maps from: pig_detail.py _build_content() BREEDING section.
    private var breedingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Breeding")

            infoRow("Lock", pig.breedingLocked ? "LOCKED" : "Unlocked")
            infoRow("Status", formatBreedingStatus(pig, verbose: true))

            if pig.isBaby {
                infoRow("Auto-sell", pig.markedForSale ? "Yes" : "No")
            }
        }
    }
}
```

### Family Section

```swift
extension PigDetailView {
    /// Parent names with fallbacks for sold/unknown parents.
    ///
    /// Maps from: pig_detail.py _build_content() FAMILY section.
    private var familySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Family")

            infoRow("Mother", parentName(id: pig.motherID, storedName: pig.motherName))
            infoRow("Father", parentName(id: pig.fatherID, storedName: pig.fatherName))
        }
    }

    /// Get the display name for a parent pig.
    ///
    /// Maps from: pig_detail.py _get_parent_name()
    private func parentName(id: UUID?, storedName: String?) -> String {
        guard let parentID = id else {
            return "Unknown (adopted/starter)"
        }
        if let parent = gameState.getGuineaPig(parentID) {
            return parent.name
        }
        if let name = storedName {
            return "\(name) (sold)"
        }
        return "Unknown (no longer on farm)"
    }
}
```

### Genetics Section

```swift
extension PigDetailView {
    /// Genotype display (only visible if the player has built a Genetics Lab).
    ///
    /// Maps from: pig_detail.py _build_content() GENETICS section.
    /// The Python version checks has_lab = bool(state.get_facilities_by_type(GENETICS_LAB)).
    @ViewBuilder
    private var geneticsSection: some View {
        let hasLab = !gameState.getFacilitiesByType(.geneticsLab).isEmpty
        if hasLab {
            VStack(alignment: .leading, spacing: 4) {
                sectionHeader("Genetics")

                let g = pig.genotype
                Text("E(\(g.eLocus.first)/\(g.eLocus.second)) "
                    + "B(\(g.bLocus.first)/\(g.bLocus.second)) "
                    + "S(\(g.sLocus.first)/\(g.sLocus.second)) "
                    + "C(\(g.cLocus.first)/\(g.cLocus.second)) "
                    + "R(\(g.rLocus.first)/\(g.rLocus.second))")
                    .font(.system(.body, design: .monospaced))

                let carriers = Genetics.carrierSummary(g)
                infoRow("Carries", carriers == "None"
                        ? "No hidden alleles" : carriers)
            }
        }
    }
}
```

### AI State Section

```swift
extension PigDetailView {
    /// Current behavior state, target description, urgent need.
    ///
    /// Maps from: pig_detail.py _build_content() AI STATE section and
    /// pig_sidebar.py refresh_content() AI State section.
    private var aiStateSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("AI State")

            if let desc = pig.targetDescription {
                Text(desc).font(.body)
            } else {
                Text(pig.behaviorState.rawValue)
                    .font(.body)
            }

            if !pig.path.isEmpty {
                Text("\(pig.path.count) steps away")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

### Recent Activity Section

```swift
extension PigDetailView {
    /// Behavior log (most recent 5 entries).
    ///
    /// Maps from: pig_detail.py _build_content() RECENT ACTIVITY section.
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Recent Activity")

            if pig.behaviorLog.isEmpty {
                Text("(no activity)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(
                    Array(pig.behaviorLog.suffix(5).reversed().enumerated()),
                    id: \.offset
                ) { _, entry in
                    Text(entry)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
    }
}
```

### Helper Methods

```swift
extension PigDetailView {
    /// Section header with bold styling.
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.top, 4)
    }

    /// A labeled info row.
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.body)
        }
    }
}
```

---

## 7. BreedingView (Pair Selection + Program)

**Maps from:** `ui/screens/breeding.py` (571 lines) -- `BreedingScreen` with `TabbedContent` (Program, Pair), and `ui/widgets/breeding_program_panel.py` (280 lines) -- `BreedingProgramPanel` keyboard-navigated config.

**Swift file:** `BigPigFarm/Views/BreedingView.swift`

### Architecture

The Python `BreedingScreen` has two tabs: "Program" (breeding program configuration) and "Pair" (manual pair selection with offspring prediction). The SwiftUI version uses a `TabView` with two tabs. The Python keyboard-navigated grid of toggles becomes touch-friendly SwiftUI `Toggle` rows and `Picker` controls.

### Type Signature

```swift
import SwiftUI

/// Breeding screen with two tabs: Program (breeding program config) and
/// Pair (manual pair selection with offspring prediction).
///
/// Maps from: ui/screens/breeding.py (BreedingScreen class) +
/// ui/widgets/breeding_program_panel.py (BreedingProgramPanel class)
struct BreedingView: View {
    let gameState: GameState

    @State private var selectedTab: BreedingTab = .program
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                ProgramTab(gameState: gameState)
                    .tabItem { Label("Program", systemImage: "gear") }
                    .tag(BreedingTab.program)

                PairTab(gameState: gameState)
                    .tabItem { Label("Pair", systemImage: "heart.fill") }
                    .tag(BreedingTab.pair)
            }
            .navigationTitle("Breeding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    breedingStatusBanner
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Breeding screen tabs.
enum BreedingTab: String, Sendable {
    case program
    case pair
}
```

### Breeding Status Banner

```swift
extension BreedingView {
    /// Compact banner showing current pair and program status.
    ///
    /// Maps from: breeding.py _update_status()
    @ViewBuilder
    private var breedingStatusBanner: some View {
        HStack(spacing: 8) {
            if let pair = gameState.breedingPair {
                let male = gameState.getGuineaPig(pair.maleID)
                let female = gameState.getGuineaPig(pair.femaleID)
                if let male, let female {
                    Text("\(male.name) x \(female.name)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if gameState.breedingProgram.enabled {
                Text("Program ON")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
    }
}
```

### Program Tab

```swift
/// Breeding program configuration panel.
///
/// Maps from: ui/widgets/breeding_program_panel.py (BreedingProgramPanel class).
/// The Python version uses a keyboard-navigated grid of checkboxes and
/// a cycle selector. The SwiftUI version uses native Toggle and Picker controls.
private struct ProgramTab: View {
    let gameState: GameState

    var body: some View {
        Form {
            // Enabled toggle
            Section {
                Toggle(
                    "Program Enabled",
                    isOn: Binding(
                        get: { gameState.breedingProgram.enabled },
                        set: { gameState.breedingProgram.enabled = $0 }
                    )
                )
            }

            // Target traits
            Section("Target Colors") {
                targetColorToggles
            }

            Section("Target Patterns") {
                targetPatternToggles
            }

            Section("Target Intensity") {
                targetIntensityToggles
            }

            Section("Target Roan") {
                targetRoanToggles
            }

            // Settings
            Section("Settings") {
                // Auto-pair toggle
                Toggle(
                    "Auto-Pair",
                    isOn: Binding(
                        get: { gameState.breedingProgram.autoPair },
                        set: { gameState.breedingProgram.autoPair = $0 }
                    )
                )

                // Keep carriers toggle
                HStack {
                    Toggle(
                        "Keep Carriers",
                        isOn: Binding(
                            get: { gameState.breedingProgram.keepCarriers },
                            set: { gameState.breedingProgram.keepCarriers = $0 }
                        )
                    )
                }
                let hasLab = !gameState.getFacilitiesByType(.geneticsLab).isEmpty
                if !hasLab {
                    Text("(needs Genetics Lab)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Strategy picker
                Picker("Strategy", selection: Binding(
                    get: { gameState.breedingProgram.strategy },
                    set: { gameState.breedingProgram.strategy = $0 }
                )) {
                    Text("Target").tag(BreedingStrategy.target)
                    Text("Diversity").tag(BreedingStrategy.diversity)
                    Text("Money").tag(BreedingStrategy.money)
                }
                .pickerStyle(.segmented)

                // Stock limit stepper
                Stepper(
                    "Stock Limit: \(gameState.breedingProgram.stockLimit)",
                    value: Binding(
                        get: { gameState.breedingProgram.stockLimit },
                        set: { gameState.breedingProgram.stockLimit = $0 }
                    ),
                    in: 2...gameState.capacity
                )
            }
        }
    }
}
```

### Target Trait Toggles

```swift
extension ProgramTab {
    /// Color target toggles.
    ///
    /// Maps from: breeding_program_panel.py _AXES[0] (Color axis).
    private var targetColorToggles: some View {
        ForEach(BaseColor.allCases, id: \.self) { color in
            Toggle(
                color.rawValue.capitalized,
                isOn: Binding(
                    get: { gameState.breedingProgram.targetColors.contains(color) },
                    set: { isOn in
                        if isOn {
                            gameState.breedingProgram.targetColors.insert(color)
                        } else {
                            gameState.breedingProgram.targetColors.remove(color)
                        }
                    }
                )
            )
        }
    }

    /// Pattern target toggles.
    private var targetPatternToggles: some View {
        ForEach(Pattern.allCases, id: \.self) { pattern in
            Toggle(
                pattern.rawValue.capitalized,
                isOn: Binding(
                    get: { gameState.breedingProgram.targetPatterns.contains(pattern) },
                    set: { isOn in
                        if isOn {
                            gameState.breedingProgram.targetPatterns.insert(pattern)
                        } else {
                            gameState.breedingProgram.targetPatterns.remove(pattern)
                        }
                    }
                )
            )
        }
    }

    /// Intensity target toggles.
    private var targetIntensityToggles: some View {
        ForEach(ColorIntensity.allCases, id: \.self) { intensity in
            Toggle(
                intensity.rawValue.capitalized,
                isOn: Binding(
                    get: { gameState.breedingProgram.targetIntensities.contains(intensity) },
                    set: { isOn in
                        if isOn {
                            gameState.breedingProgram.targetIntensities.insert(intensity)
                        } else {
                            gameState.breedingProgram.targetIntensities.remove(intensity)
                        }
                    }
                )
            )
        }
    }

    /// Roan target toggles.
    private var targetRoanToggles: some View {
        ForEach(RoanType.allCases, id: \.self) { roan in
            Toggle(
                roan == .none ? "Standard" : "Roan",
                isOn: Binding(
                    get: { gameState.breedingProgram.targetRoan.contains(roan) },
                    set: { isOn in
                        if isOn {
                            gameState.breedingProgram.targetRoan.insert(roan)
                        } else {
                            gameState.breedingProgram.targetRoan.remove(roan)
                        }
                    }
                )
            )
        }
    }
}
```

### Pair Tab

```swift
/// Manual breeding pair selection with offspring prediction.
///
/// Maps from: breeding.py Pair tab -- two ListViews (male, female) with
/// info panels and a prediction panel below.
private struct PairTab: View {
    let gameState: GameState

    @State private var selectedMaleID: UUID?
    @State private var selectedFemaleID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Parent selection (two columns)
            HStack(spacing: 0) {
                // Males column
                VStack(alignment: .leading) {
                    Text("Males")
                        .font(.headline)
                        .padding(.horizontal)
                    List(adultMales, id: \.id, selection: $selectedMaleID) { pig in
                        BreedingPigRow(pig: pig, gameState: gameState)
                    }
                    .listStyle(.plain)
                }

                Divider()

                // Females column
                VStack(alignment: .leading) {
                    Text("Females")
                        .font(.headline)
                        .padding(.horizontal)
                    List(adultFemales, id: \.id, selection: $selectedFemaleID) { pig in
                        BreedingPigRow(pig: pig, gameState: gameState)
                    }
                    .listStyle(.plain)
                }
            }
            .frame(height: 200)

            Divider()

            // Prediction panel
            predictionPanel
                .frame(maxHeight: .infinity)
        }
    }

    /// All adult male pigs.
    private var adultMales: [GuineaPig] {
        gameState.getPigsList()
            .filter { $0.gender == .male && $0.isAdult }
    }

    /// All adult female pigs.
    private var adultFemales: [GuineaPig] {
        gameState.getPigsList()
            .filter { $0.gender == .female && $0.isAdult }
    }
}
```

### Breeding Pig Row

```swift
/// A row in the breeding pair selection list.
///
/// Maps from: breeding.py PigListItem class.
private struct BreedingPigRow: View {
    let pig: GuineaPig
    let gameState: GameState

    var body: some View {
        HStack {
            Text(pig.name)
                .font(.body)

            Spacer()

            Text(pig.phenotype.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Status badges
            if isPaired {
                Text(isAutoPaired ? "AUTO" : "PAIRED")
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.blue.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else if pig.breedingLocked {
                Text("LOCKED")
                    .font(.caption2)
                    .foregroundStyle(.red)
            } else if pig.isPregnant {
                Text("Pregnant")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            } else if !pig.canBreed {
                Text("Can't breed")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var isPaired: Bool {
        guard let pair = gameState.breedingPair else { return false }
        return pig.id == pair.maleID || pig.id == pair.femaleID
    }

    private var isAutoPaired: Bool {
        isPaired && gameState.breedingProgram.shouldAutoPair
    }
}
```

### Prediction Panel

```swift
extension PairTab {
    /// Offspring prediction panel showing phenotype probabilities.
    ///
    /// Maps from: breeding.py _update_predictions()
    @ViewBuilder
    private var predictionPanel: some View {
        let male = selectedMaleID.flatMap { gameState.getGuineaPig($0) }
        let female = selectedFemaleID.flatMap { gameState.getGuineaPig($0) }

        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if let male, let female {
                    Text("Offspring: \(male.name) x \(female.name)")
                        .font(.headline)

                    // Warnings
                    if let reason = male.breedingBlockReason {
                        Text("\(male.name): \(reason)")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    if let reason = female.breedingBlockReason {
                        Text("\(female.name): \(reason)")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    // Phenotype predictions
                    let predictions = Genetics.predictOffspringPhenotypes(
                        male.genotype, female.genotype
                    )
                    ForEach(
                        Array(predictions.prefix(8).enumerated()),
                        id: \.offset
                    ) { _, prediction in
                        PredictionRow(
                            phenotype: prediction.phenotype,
                            probability: prediction.probability,
                            isNew: !gameState.pigdex.isDiscovered(
                                phenotypeKey(prediction.phenotype)
                            )
                        )
                    }

                    if predictions.count > 8 {
                        Text("... and \(predictions.count - 8) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Target probability
                    let program = gameState.breedingProgram
                    if program.hasTarget {
                        let targetProb = Genetics.calculateTargetProbability(
                            male.genotype, female.genotype,
                            targetColors: program.targetColors,
                            targetPatterns: program.targetPatterns,
                            targetIntensities: program.targetIntensities,
                            targetRoan: program.targetRoan
                        )
                        Text("Target probability: \(targetProb * 100, specifier: "%.1f")%")
                            .font(.body.bold())
                            .padding(.top, 4)
                    }

                    // Pair action buttons
                    HStack {
                        Button("Set Pair") {
                            setPair(male: male, female: female)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSetPair(male: male, female: female))

                        if gameState.breedingPair != nil {
                            Button("Cancel Pair", role: .destructive) {
                                gameState.clearBreedingPair()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.top, 8)
                } else {
                    Text("Select a male and female to see offspring predictions")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            }
            .padding()
        }
    }

    /// Set the selected pair as the active breeding pair.
    ///
    /// Maps from: breeding.py action_set_pair()
    private func setPair(male: GuineaPig, female: GuineaPig) {
        guard !female.isPregnant else { return }
        guard !male.breedingLocked, !female.breedingLocked else { return }
        gameState.setBreedingPair(maleID: male.id, femaleID: female.id)
    }

    /// Whether the pair can be set.
    private func canSetPair(male: GuineaPig, female: GuineaPig) -> Bool {
        !female.isPregnant && !male.breedingLocked && !female.breedingLocked
    }
}
```

### Prediction Row

```swift
/// A row showing a predicted offspring phenotype and its probability.
///
/// Maps from: breeding.py _update_predictions() bar rendering.
private struct PredictionRow: View {
    let phenotype: Phenotype
    let probability: Double
    let isNew: Bool

    var body: some View {
        HStack {
            // Probability bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(.secondary.opacity(0.2))
                    Rectangle()
                        .fill(.blue)
                        .frame(width: geometry.size.width * probability)
                }
            }
            .frame(width: 80, height: 12)
            .clipShape(RoundedRectangle(cornerRadius: 3))

            Text("\(probability * 100, specifier: "%.1f")%")
                .font(.caption)
                .frame(width: 40, alignment: .trailing)

            Text(phenotype.displayName)
                .font(.caption)

            if isNew {
                Text("NEW")
                    .font(.caption2.bold())
                    .foregroundStyle(.green)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.green.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }
}
```

---

## 8. AlmanacView (Pigdex + Contracts + Log)

**Maps from:** `ui/screens/almanac.py` (310 lines) -- `JournalScreen` with 3 tabs: Pigdex, Contracts, Event Log.

**Swift file:** `BigPigFarm/Views/AlmanacView.swift`

### Architecture

The Python `JournalScreen` uses `TabbedContent` with 3 `TabPane` children, each containing a custom `Static` widget (`PigdexPanel`, `ContractsPanel`, `EventLogPanel`). The SwiftUI version uses `TabView` with 3 tabs.

### Type Signature

```swift
import SwiftUI

/// Journal screen with 3 tabs: Pigdex, Contracts, and Event Log.
///
/// Maps from: ui/screens/almanac.py (JournalScreen class)
///
/// Presented as a .sheet from ContentView.
struct AlmanacView: View {
    let gameState: GameState

    @State private var selectedTab: AlmanacTab = .pigdex
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                PigdexTab(gameState: gameState)
                    .tabItem { Label("Pigdex", systemImage: "book.fill") }
                    .tag(AlmanacTab.pigdex)

                ContractsTab(gameState: gameState)
                    .tabItem { Label("Contracts", systemImage: "doc.text.fill") }
                    .tag(AlmanacTab.contracts)

                EventLogTab(gameState: gameState)
                    .tabItem { Label("Log", systemImage: "clock.fill") }
                    .tag(AlmanacTab.log)
            }
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Journal tabs.
enum AlmanacTab: String, Sendable {
    case pigdex
    case contracts
    case log
}
```

### Pigdex Tab

```swift
/// Pigdex collection grid showing 144 phenotype discovery slots.
///
/// Maps from: almanac.py PigdexPanel class.
///
/// The Python version renders a text-based grid with color/pattern/intensity
/// rows and columns. The SwiftUI version uses a LazyVGrid for a more
/// compact, touch-friendly layout.
private struct PigdexTab: View {
    let gameState: GameState

    /// All 8 base colors, used as column headers.
    private let allColors = BaseColor.allCases

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Progress header
                let pigdex = gameState.pigdex
                Text("\(pigdex.discoveredCount)/\(pigdex.totalPossible) Discovered (\(Int(pigdex.completionPercent))%)")
                    .font(.headline)

                ProgressView(value: pigdex.completionPercent, total: 100)
                    .padding(.bottom, 8)

                // Phenotype grid: rows = roan x intensity x pattern, cols = color
                ForEach(RoanType.allCases, id: \.self) { roan in
                    Text(roan == .roan ? "ROAN" : "STANDARD")
                        .font(.subheadline.bold())
                        .padding(.top, 4)

                    ForEach(ColorIntensity.allCases, id: \.self) { intensity in
                        Text(intensity.rawValue.capitalized)
                            .font(.caption.bold())

                        ForEach(Pattern.allCases, id: \.self) { pattern in
                            PigdexRow(
                                pattern: pattern,
                                intensity: intensity,
                                roan: roan,
                                pigdex: pigdex
                            )
                        }
                    }
                }

                // Milestones
                Divider()
                milestonesSection
            }
            .padding()
        }
    }

    /// Milestone progress display.
    ///
    /// Maps from: almanac.py PigdexPanel._build_content() milestones section.
    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Milestones")
                .font(.headline)

            HStack(spacing: 16) {
                ForEach([25, 50, 75, 100], id: \.self) { threshold in
                    let pct = gameState.pigdex.completionPercent
                    let claimed = gameState.pigdex.milestoneRewardsClaimed
                        .contains(threshold)
                    VStack {
                        Text("\(threshold)%")
                            .font(.caption.bold())
                        if claimed {
                            Text("CLAIMED")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        } else if pct >= Double(threshold) {
                            Text("READY!")
                                .font(.caption2.bold())
                                .foregroundStyle(.yellow)
                        } else {
                            Text("\(Int(pct))/\(threshold)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
```

### Pigdex Row

```swift
/// A single row of 8 color slots for one pattern/intensity/roan combination.
///
/// Maps from: almanac.py PigdexPanel grid row rendering.
private struct PigdexRow: View {
    let pattern: Pattern
    let intensity: ColorIntensity
    let roan: RoanType
    let pigdex: Pigdex

    var body: some View {
        HStack(spacing: 4) {
            Text(pattern.rawValue.capitalized)
                .font(.caption2)
                .frame(width: 60, alignment: .leading)

            ForEach(BaseColor.allCases, id: \.self) { color in
                let key = phenotypeKeyFromParts(
                    baseColor: color,
                    pattern: pattern,
                    intensity: intensity,
                    roan: roan
                )
                let discovered = pigdex.isDiscovered(key)

                Circle()
                    .fill(discovered
                          ? pigColorSwiftUI(color)
                          : Color.secondary.opacity(0.2))
                    .frame(width: 16, height: 16)
                    .overlay {
                        if discovered {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
            }
        }
    }
}
```

### Contracts Tab

```swift
/// Active breeding contracts list.
///
/// Maps from: almanac.py ContractsPanel class.
private struct ContractsTab: View {
    let gameState: GameState

    var body: some View {
        List {
            let board = gameState.contractBoard

            Section("Active Contracts (\(board.activeContracts.count))") {
                if board.activeContracts.isEmpty {
                    Text("No active contracts. Check back later!")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(board.activeContracts, id: \.id) { contract in
                        ContractRow(
                            contract: contract,
                            currentDay: gameState.gameTime.day
                        )
                    }
                }
            }

            Section("Statistics") {
                infoRow("Completed", "\(board.completedContracts)")
                infoRow("Total Earnings",
                        Currency.format(board.totalContractEarnings))
                infoRow("Current Day", "Day \(gameState.gameTime.day)")
            }
        }
        .listStyle(.insetGrouped)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}

/// A single contract row.
///
/// Maps from: almanac.py ContractsPanel._format_contract()
private struct ContractRow: View {
    let contract: BreedingContract
    let currentDay: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(contract.description)
                .font(.body)

            HStack {
                Text(contract.difficulty.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(difficultyColor.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Text("+\(contract.reward) Squeaks")
                    .font(.caption)
                    .foregroundStyle(.green)

                Spacer()

                let daysLeft = max(0, contract.deadlineDay - currentDay)
                Text("\(daysLeft)d left")
                    .font(.caption)
                    .foregroundStyle(daysLeft < 5 ? .red : .secondary)
            }

            if let hint = contract.breedingHint {
                Text("Tip: \(hint)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding(.vertical, 2)
    }

    private var difficultyColor: Color {
        switch contract.difficulty {
        case .easy: return .green
        case .medium: return .yellow
        case .hard: return .orange
        case .expert: return .red
        case .legendary: return .purple
        }
    }
}
```

### Event Log Tab

```swift
/// Scrollable event history.
///
/// Maps from: almanac.py EventLogPanel class.
private struct EventLogTab: View {
    let gameState: GameState

    var body: some View {
        List {
            Section("Events (\(gameState.events.count))") {
                if gameState.events.isEmpty {
                    Text("No events yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(
                        Array(gameState.events.reversed().enumerated()),
                        id: \.offset
                    ) { _, event in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: eventIcon(event.eventType))
                                .foregroundStyle(eventColor(event.eventType))
                                .font(.caption)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.message)
                                    .font(.body)
                                Text("Day \(event.gameDay)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    /// Map event type to SF Symbol name.
    ///
    /// Maps from: almanac.py EVENT_ICONS dictionary.
    private func eventIcon(_ type: String) -> String {
        switch type {
        case "birth": return "gift.fill"
        case "death": return "heart.slash.fill"
        case "sale": return "dollarsign.circle.fill"
        case "purchase": return "cart.fill"
        case "breeding": return "heart.fill"
        case "mutation": return "sparkles"
        case "pigdex": return "book.fill"
        case "contract": return "doc.text.fill"
        case "adoption": return "heart.circle.fill"
        default: return "bell.fill"
        }
    }

    /// Map event type to a display color.
    private func eventColor(_ type: String) -> Color {
        switch type {
        case "birth": return .green
        case "death": return .red
        case "sale": return .yellow
        case "purchase": return .blue
        case "breeding": return .pink
        case "mutation": return .purple
        case "pigdex": return .orange
        case "contract": return .cyan
        case "adoption": return .mint
        default: return .secondary
        }
    }
}
```

---

## 9. BiomeSelectView (Modal Picker)

**Maps from:** `ui/screens/biome_select.py` (179 lines) -- `BiomeSelectScreen` modal with biome list, tier-gating, and detail panel.

**Swift file:** `BigPigFarm/Views/BiomeSelectView.swift`

### Architecture

The Python `BiomeSelectScreen` is a `ModalScreen[BiomeType | None]` that returns the selected biome to the caller via a callback. The SwiftUI version is presented as a `.sheet` from the Upgrades tab of `ShopView`, with a callback closure for the selection.

### Type Signature

```swift
import SwiftUI

/// Modal biome picker for selecting a biome when adding a new room.
///
/// Maps from: ui/screens/biome_select.py (BiomeSelectScreen class)
///
/// Presented as a .sheet from the Upgrades tab. Shows all biomes with
/// tier-locked items dimmed. Selecting a biome calls onBiomeSelected.
struct BiomeSelectView: View {
    /// Current farm tier (determines which biomes are available).
    let farmTier: Int

    /// Biomes already built (shown as "Built" and disabled).
    let existingBiomes: Set<BiomeType>

    /// Callback when a biome is selected. Nil means cancelled.
    var onBiomeSelected: (BiomeType?) -> Void

    /// The currently highlighted biome for the detail panel.
    @State private var highlightedBiome: BiomeType?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List(BiomeType.allCases, id: \.self) { biomeType in
                    let info = biomes[biomeType]
                    let (available, lockReason) = biomeStatus(biomeType)

                    BiomeRow(
                        biomeType: biomeType,
                        info: info,
                        available: available,
                        lockReason: lockReason
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        highlightedBiome = biomeType
                        if available {
                            onBiomeSelected(biomeType)
                            dismiss()
                        }
                    }
                }
                .listStyle(.plain)

                // Detail panel
                if let biome = highlightedBiome,
                   let info = biomes[biome] {
                    biomeDetail(info: info, biome: biome)
                }
            }
            .navigationTitle("Select Biome")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        onBiomeSelected(nil)
                        dismiss()
                    }
                }
            }
        }
    }
}
```

### Biome Status

```swift
extension BiomeSelectView {
    /// Determine whether a biome is available for selection.
    ///
    /// Maps from: biome_select.py BiomeSelectScreen._biome_status()
    private func biomeStatus(_ biome: BiomeType) -> (Bool, String?) {
        guard let info = biomes[biome] else { return (false, "unknown") }

        if existingBiomes.contains(biome) {
            return (false, "Built")
        }
        if info.requiredTier > farmTier {
            return (false, "Tier \(info.requiredTier)")
        }

        // Check prerequisite: all lower tiers must have at least one biome built
        let coveredTiers = Set(existingBiomes.compactMap { biomes[$0]?.requiredTier })
        for tier in 1..<info.requiredTier {
            if !coveredTiers.contains(tier) {
                return (false, "Build a tier \(tier) biome first")
            }
        }

        return (true, nil)
    }
}
```

### Biome Row and Detail

```swift
/// A single biome row in the selection list.
///
/// Maps from: biome_select.py BiomeListItem class.
private struct BiomeRow: View {
    let biomeType: BiomeType
    let info: BiomeInfo?
    let available: Bool
    let lockReason: String?

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(info?.displayName ?? biomeType.rawValue.capitalized)
                    .font(.body)
                if let reason = lockReason {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            Spacer()
            if let info {
                if info.cost > 0 {
                    CurrencyLabel(amount: info.cost)
                } else {
                    Text("Free")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .opacity(available ? 1.0 : 0.4)
    }
}

extension BiomeSelectView {
    /// Detail panel for the highlighted biome.
    ///
    /// Maps from: biome_select.py _update_detail()
    private func biomeDetail(info: BiomeInfo, biome: BiomeType) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(info.displayName)
                .font(.headline)
            Text(info.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                let costStr = info.cost > 0
                    ? Currency.format(info.cost) : "Free"
                Text("Cost: \(costStr)")
                    .font(.caption)
                Text("Happiness: +\(info.happinessBonus, specifier: "%.1f")/hr")
                    .font(.caption)
            }

            // Mutation boosts
            if !info.mutationBoostLoci.isEmpty {
                let boosts = info.mutationBoostLoci.map { locus, rate in
                    let name = locus.replacingOccurrences(of: "Locus", with: "")
                        .uppercased()
                    return "\(name) +\(Int(rate * 100))%"
                }
                Text("Mutation boosts: \(boosts.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial)
    }
}
```

---

## 10. AdoptionView (Bloodline Adoption)

**Maps from:** `ui/screens/adoption.py` (73 lines) -- `calculate_adoption_cost()` and `generate_adoption_pig()` functions, integrated into `shop.py` as the Adoption tab.

**Swift file:** `BigPigFarm/Views/AdoptionView.swift`

### Architecture

The Python adoption interface is a tab of the `ShopScreen` that shows 3-5 randomly generated pigs. The SwiftUI version is a standalone `View` used as the Adoption tab of `ShopView.TabView`. It generates pigs on appear and offers a "Refresh" action to reroll.

### Type Signature

```swift
import SwiftUI

/// Adoption center showing randomly generated pigs available for purchase.
///
/// Maps from: ui/screens/adoption.py (generate_adoption_pig, calculate_adoption_cost)
/// and shop.py ShopScreen ADOPTION category handling.
///
/// Used as the Adoption tab in ShopView. Can also be presented standalone.
struct AdoptionView: View {
    let gameState: GameState

    /// The current batch of available pigs.
    @State private var availablePigs: [GuineaPig] = []

    /// The selected pig for the detail panel.
    @State private var selectedPig: GuineaPig?

    /// Error alert state.
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            List(availablePigs, id: \.id) { pig in
                let cost = Adoption.calculateAdoptionCost(pig, state: gameState)
                let canAfford = gameState.money >= cost

                AdoptionPigRow(pig: pig, cost: cost, canAfford: canAfford)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedPig = pig }
            }
            .listStyle(.plain)
            .overlay {
                if availablePigs.isEmpty {
                    ContentUnavailableView(
                        "No Pigs Available",
                        systemImage: "pawprint",
                        description: Text("Tap Refresh to generate new pigs")
                    )
                }
            }

            // Detail panel for selected pig
            if let pig = selectedPig {
                adoptionDetail(pig: pig)
            }
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button {
                    refreshPigs()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            if availablePigs.isEmpty {
                refreshPigs()
            }
        }
        .alert("Cannot Adopt", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
}
```

### Adoption Pig Row

```swift
/// A single row showing a pig available for adoption.
///
/// Maps from: shop.py AdoptionPigWidget class.
private struct AdoptionPigRow: View {
    let pig: GuineaPig
    let cost: Int
    let canAfford: Bool

    var body: some View {
        HStack {
            Circle()
                .fill(pigColorSwiftUI(pig.phenotype.baseColor))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(pig.name)
                        .font(.body)
                    Text(pig.gender == .male ? "M" : "F")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(pig.phenotype.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    RarityBadge(rarity: pig.phenotype.rarity)
                    if let tag = pig.originTag {
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.purple.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }

            Spacer()

            CurrencyLabel(amount: cost)
                .foregroundStyle(canAfford ? .primary : .red)
        }
    }
}
```

### Adoption Detail and Actions

```swift
extension AdoptionView {
    /// Detail panel for the selected adoption pig.
    ///
    /// Maps from: shop.py _update_detail() adoption pig branch.
    private func adoptionDetail(pig: GuineaPig) -> some View {
        let cost = Adoption.calculateAdoptionCost(pig, state: gameState)
        let canAfford = gameState.money >= cost

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(pig.name).font(.headline)
                Spacer()
                CurrencyLabel(amount: cost)
            }

            HStack {
                Text("Gender: \(pig.gender == .male ? "Male" : "Female")")
                    .font(.caption)
                Text("Color: \(pig.phenotype.displayName)")
                    .font(.caption)
            }

            HStack {
                Text("Rarity: \(pig.phenotype.rarity.rawValue.capitalized)")
                    .font(.caption)
                let traits = pig.personality.map { $0.rawValue.capitalized }
                Text("Traits: \(traits.joined(separator: ", "))")
                    .font(.caption)
            }

            if let tag = pig.originTag {
                Text("Bloodline: \(tag)")
                    .font(.caption)
                    .foregroundStyle(.purple)
            }

            Text("Farm: \(gameState.pigCount)/\(gameState.capacity) pigs")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Adopt \(pig.name)") { adoptPig(pig) }
                .buttonStyle(.borderedProminent)
                .disabled(!canAfford || gameState.isAtCapacity)
        }
        .padding()
        .background(.regularMaterial)
    }

    /// Adopt the selected pig.
    ///
    /// Maps from: shop.py _adopt_pig()
    private func adoptPig(_ pig: GuineaPig) {
        guard !gameState.isAtCapacity else {
            errorMessage = "Farm is at capacity! Upgrade or sell pigs."
            showError = true
            return
        }

        let cost = Adoption.calculateAdoptionCost(pig, state: gameState)
        guard gameState.money >= cost else {
            errorMessage = "Not enough Squeaks!"
            showError = true
            return
        }

        guard let position = Adoption.findSpawnPosition(in: gameState) else {
            errorMessage = "No space for new pig!"
            showError = true
            return
        }

        var adoptedPig = pig
        adoptedPig.position = Position(x: Double(position.x), y: Double(position.y))

        _ = gameState.spendMoney(cost)
        gameState.addGuineaPig(adoptedPig)

        gameState.logEvent(
            "Adopted \(pig.name) (\(pig.phenotype.displayName)) for \(cost) Squeaks",
            eventType: "adoption"
        )

        availablePigs.removeAll { $0.id == pig.id }
        selectedPig = nil
    }

    /// Generate a fresh batch of adoption pigs.
    ///
    /// Maps from: shop.py _generate_available_pigs()
    private func refreshPigs() {
        let existingNames = Set(gameState.getPigsList().map(\.name))
            .union(Set(availablePigs.map(\.name)))

        availablePigs = Adoption.generateAdoptionBatch(
            existingNames: existingNames,
            farmTier: gameState.farmTier,
            count: Int.random(in: 3...5)
        )
        selectedPig = nil
    }
}
```

### Decision Needed: Adoption Module Location

The Python adoption logic lives in `ui/screens/adoption.py` -- a UI file. For the iOS port, the pure logic functions (`calculateAdoptionCost`, `generateAdoptionPig`, `findSpawnPosition`) should live in a non-UI location. Two options:

1. **`Economy/Adoption.swift`** -- alongside Shop, Market, Contracts. This fits because adoption is an economic transaction.
2. **Keep in `Views/AdoptionView.swift`** -- simpler but violates the dependency rule (views should not contain business logic).

**Recommendation:** Create `Economy/Adoption.swift` with the logic functions as a caseless `enum Adoption` namespace. `AdoptionView` calls into `Adoption.calculateAdoptionCost()` etc. This follows the same pattern as `Shop`, `Market`, and `Currency`.

---

## 11. SharedComponents

**Maps from:** `ui/utils.py` (73 lines) -- `format_needs_bar()`, `format_breeding_status()`, `format_facility_bonuses()`. Also new components for iOS-native presentation.

**Swift file:** `BigPigFarm/Views/SharedComponents.swift`

### CurrencyLabel

```swift
import SwiftUI

/// Displays a formatted currency amount with the Squeaks icon.
///
/// Maps from: economy/currency.py format_currency()
///
/// Used in StatusBarView, ShopView, PigListView, PigDetailView.
struct CurrencyLabel: View {
    let amount: Int

    var body: some View {
        Text(Currency.format(amount))
            .font(.caption.bold())
            .foregroundStyle(.yellow)
    }
}
```

### NeedBar

```swift
/// A horizontal bar visualizing a pig need level (0.0 to 1.0).
///
/// Maps from: ui/utils.py format_needs_bar()
///
/// Used in PigDetailView needs section, PigListView row, and StatusBarView
/// resource indicators.
struct NeedBar: View {
    /// The need value, normalized to 0.0-1.0.
    let value: Double

    /// The label displayed to the left of the bar.
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            if !label.isEmpty {
                Text(label)
                    .font(.caption)
                    .frame(width: 60, alignment: .leading)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.secondary.opacity(0.2))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(needColor)
                        .frame(width: max(0, geometry.size.width * value))
                }
            }
            .frame(height: 8)

            Text("\(Int(value * 100))%")
                .font(.caption2)
                .frame(width: 30, alignment: .trailing)
        }
    }

    /// Color based on the need level.
    private var needColor: Color {
        if value >= 0.7 { return .green }
        if value >= 0.4 { return .yellow }
        return .red
    }
}
```

### RarityBadge

```swift
/// Displays a colored rarity badge.
///
/// Used in PigListView rows, PigDetailView header, ShopView items.
struct RarityBadge: View {
    let rarity: Rarity

    var body: some View {
        Text(rarity.rawValue.capitalized)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(.white)
            .background(rarityColor)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    /// Maps rarity to a display color.
    private var rarityColor: Color {
        switch rarity {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .veryRare: return .purple
        case .legendary: return .orange
        }
    }
}
```

### BreedingStatusLabel

```swift
/// Displays a concise breeding status for a pig.
///
/// Maps from: ui/utils.py format_breeding_status()
struct BreedingStatusLabel: View {
    let pig: GuineaPig

    var body: some View {
        Text(formatBreedingStatus(pig, verbose: false))
            .font(.caption2)
            .foregroundStyle(statusColor)
    }

    private var statusColor: Color {
        if pig.canBreed { return .green }
        if pig.breedingLocked { return .red }
        if pig.isPregnant { return .orange }
        return .secondary
    }
}
```

### FacilityBonusLabel

```swift
/// Displays facility bonuses as a compact summary.
///
/// Maps from: ui/utils.py format_facility_bonuses()
struct FacilityBonusLabel: View {
    let facilityType: FacilityType

    var body: some View {
        let bonuses = formatFacilityBonuses(facilityType)
        if !bonuses.isEmpty {
            Text(bonuses)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
```

### PigPortraitView

```swift
/// Displays a pig portrait image from the asset catalog.
///
/// Maps from: pig_detail.py _build_portrait_text() and
/// pig_sidebar.py _build_portrait(). The Python version renders
/// half-block character art at runtime. The iOS version loads a
/// pre-rendered PNG portrait from the sprite pipeline (Doc 03).
struct PigPortraitView: View {
    let baseColor: BaseColor
    let pattern: Pattern
    let intensity: ColorIntensity
    let roan: RoanType
    let pigID: UUID

    var body: some View {
        let imageName = SpriteAssets.portraitImageName(
            baseColor: baseColor,
            pattern: pattern,
            intensity: intensity,
            roan: roan
        )
        Image(imageName)
            .resizable()
            .interpolation(.none) // Pixel-art crispness
            .scaledToFit()
    }
}
```

### Free Functions

```swift
/// Format a pig's breeding status as a short string.
///
/// Maps from: ui/utils.py format_breeding_status()
func formatBreedingStatus(_ pig: GuineaPig, verbose: Bool = false) -> String {
    if pig.isBaby && pig.markedForSale {
        return verbose ? "Marked for auto-sell at adulthood" : "Sell@Adult"
    }
    if pig.canBreed { return "Ready" }

    let reason = pig.breedingBlockReason
    if verbose { return reason ?? "Not ready" }

    guard let reason else { return "Not ready" }
    if reason.hasPrefix("Breeding locked") { return "LOCKED" }
    if reason.hasPrefix("Too young") { return "Baby" }
    if reason.hasPrefix("Too old") { return "Senior" }
    if reason.hasPrefix("Unhappy") { return "Not ready" }
    if reason.hasPrefix("Pregnant") { return "Pregnant" }
    if reason.hasPrefix("Recovering") { return "Recovering" }
    return "Not ready"
}

/// Format facility bonuses as a summary string.
///
/// Maps from: ui/utils.py format_facility_bonuses()
func formatFacilityBonuses(_ facilityType: FacilityType) -> String {
    guard let info = facilityInfo[facilityType] else { return "" }
    var parts: [String] = []
    if info.healthBonus > 0 { parts.append("+\(Int(info.healthBonus * 100))% health") }
    if info.happinessBonus > 0 { parts.append("+\(Int(info.happinessBonus * 100))% happiness") }
    if info.socialBonus > 0 { parts.append("+\(Int(info.socialBonus * 100))% social") }
    if info.breedingBonus > 0 { parts.append("+\(Int(info.breedingBonus * 100))% breeding") }
    if info.growthBonus > 0 { parts.append("+\(Int(info.growthBonus * 100))% growth") }
    if info.saleBonus > 0 { parts.append("+\(Int(info.saleBonus * 100))% sale value") }
    if info.foodProduction > 0 { parts.append("produces \(info.foodProduction) food") }
    return parts.joined(separator: ", ")
}

/// Map a BaseColor to a SwiftUI Color for display (color dots, etc.).
///
/// These are approximate display colors for UI elements like list row
/// indicators. The actual pig sprites use the full palette from Doc 03.
func pigColorSwiftUI(_ baseColor: BaseColor) -> Color {
    switch baseColor {
    case .black: return .black
    case .chocolate: return .brown
    case .golden: return .yellow
    case .cream: return Color(red: 1.0, green: 0.95, blue: 0.8)
    case .blue: return Color(red: 0.4, green: 0.5, blue: 0.6)
    case .lilac: return Color(red: 0.7, green: 0.5, blue: 0.7)
    case .saffron: return .orange
    case .smoke: return .gray
    }
}
```

---

## 12. ContentView Updates

**File:** `BigPigFarm/ContentView.swift`

Doc 06 Section 11 defined `ContentView` with placeholder `Text` views inside the `.sheet` modifiers. This section specifies the updates to wire the real views.

### Sheet Wiring Updates

Replace each placeholder with the actual view:

```swift
// Replace the placeholder sheets from Doc 06:

.sheet(isPresented: $showShop) {
    ShopView(gameState: gameState)
}
.sheet(isPresented: $showPigList) {
    PigListView(gameState: gameState, onFollowPig: handleFollowPig)
}
.sheet(isPresented: $showBreeding) {
    BreedingView(gameState: gameState)
}
.sheet(isPresented: $showAlmanac) {
    AlmanacView(gameState: gameState)
}
.sheet(isPresented: $showPigDetail) {
    if let pigID = selectedPigID,
       let pig = gameState.getGuineaPig(pigID) {
        NavigationStack {
            PigDetailView(gameState: gameState, pig: pig)
                .navigationTitle(pig.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showPigDetail = false }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Follow") {
                            handleFollowPig(pigID)
                            showPigDetail = false
                        }
                    }
                }
        }
    }
}
```

### Follow Pig Handler

```swift
extension ContentView {
    /// Handle follow-pig action from PigListView or PigDetailView.
    ///
    /// Maps from: main_game.py _follow_pig() and pig_list.py action_follow_pig().
    /// Dismisses the sheet and centers the camera on the pig.
    private func handleFollowPig(_ pigID: UUID) {
        selectedPigID = pigID
        showPigList = false
        showPigDetail = false

        // Tell the farm scene to center on this pig
        farmScene.centerOnPig(pigID)
    }
}
```

### FarmSceneCoordinator Completion

Complete the delegate methods that were stubbed in Doc 06:

```swift
@MainActor
class FarmSceneCoordinator: FarmSceneDelegate {
    weak var contentView: ContentView?
    private let gameState: GameState

    init(gameState: GameState) {
        self.gameState = gameState
    }

    func farmScene(_ scene: FarmScene, didSelectPig pigID: UUID) {
        // Show pig detail sheet
        contentView?.selectedPigID = pigID
        contentView?.showPigDetail = true
    }

    func farmSceneDidDeselectPig(_ scene: FarmScene) {
        contentView?.selectedPigID = nil
        contentView?.showPigDetail = false
    }

    func farmScene(_ scene: FarmScene, didSelectFacility facilityID: UUID) {
        // Edit mode facility selection is handled within FarmScene
        // (visual highlight). No sheet needed.
    }

    func farmScene(_ scene: FarmScene, didRemoveFacility facilityID: UUID) {
        if let facility = gameState.removeFacility(facilityID) {
            let refund = Shop.facilityCost(facility.facilityType)
            gameState.addMoney(refund)
            gameState.logEvent(
                "Removed \(facility.name) (+\(Currency.format(refund)))",
                eventType: "purchase"
            )
        }
    }
}
```

### Decision Needed: ContentView `@State` Properties Accessibility

The `FarmSceneCoordinator` needs to mutate `ContentView`'s `@State` properties (`selectedPigID`, `showPigDetail`). In the Doc 06 design, the coordinator holds a `weak var contentView: ContentView?` reference. However, since `ContentView` is a struct, this reference actually points to the `@State` backing storage. This pattern works in practice but is unconventional.

**Alternative:** Use `@Bindable` or pass closures to the coordinator instead of a direct reference:

```swift
class FarmSceneCoordinator: FarmSceneDelegate {
    var onPigSelected: ((UUID) -> Void)?
    var onPigDeselected: (() -> Void)?
    // ...
}
```

This is cleaner and avoids the struct reference question. The implementer should evaluate both approaches and choose the one that compiles cleanly under Swift 6 strict concurrency.

---

## 13. Testing Strategy

**Test file:** `BigPigFarmTests/SwiftUIScreensTests.swift`

### Approach

SwiftUI views are tested indirectly by testing the logic they depend on. Since all views read from `GameState` and call into `Shop`, `Market`, `Adoption`, etc., the tests verify:

1. **Data flow**: Creating a `GameState` and verifying the computed properties that views read
2. **Action logic**: Testing purchase/sell/adopt operations that views trigger
3. **Formatting helpers**: Testing `formatBreedingStatus`, `formatFacilityBonuses`, `pigColorSwiftUI`

Direct SwiftUI view testing (snapshot tests, ViewInspector) is deferred to Doc 08 polish phase.

### Test Cases

```swift
import Testing
@testable import BigPigFarm

@Test func currencyFormatting() {
    #expect(Currency.format(0) == "0 Squeaks")
    #expect(Currency.format(1000) == "1,000 Squeaks")
    #expect(Currency.format(42) == "42 Squeaks")
}

@Test func breedingStatusReady() {
    let pig = GuineaPig.create(name: "Test", gender: .male)
    // Adult pig with high happiness should be "Ready"
    var mutablePig = pig
    mutablePig.ageDays = 5.0
    mutablePig.needs.happiness = 80.0
    #expect(formatBreedingStatus(mutablePig) == "Ready")
}

@Test func breedingStatusLocked() {
    var pig = GuineaPig.create(name: "Test", gender: .male)
    pig.ageDays = 5.0
    pig.breedingLocked = true
    #expect(formatBreedingStatus(pig) == "LOCKED")
}

@Test func breedingStatusBaby() {
    let pig = GuineaPig.create(name: "Test", gender: .male)
    // Default age_days = 0 -> baby
    #expect(formatBreedingStatus(pig) == "Baby")
}

@Test func facilityBonusFormatting() {
    let bonuses = formatFacilityBonuses(.groomingStation)
    // Grooming station should have sale bonus
    #expect(bonuses.contains("sale"))
}

@Test func pigColorMapping() {
    let black = pigColorSwiftUI(.black)
    #expect(black == .black)
    // Smoke should map to gray
    let smoke = pigColorSwiftUI(.smoke)
    #expect(smoke == .gray)
}

@Test func sortCriteriaCoversAllCases() {
    // Ensure we have a sort case for each criterion
    #expect(PigSortCriterion.allCases.count == 7)
}

@Test func adoptionCostAboveSaleValue() async {
    // Adoption cost should always exceed sale value to prevent exploits
    let pig = GuineaPig.create(name: "Test", gender: .female)
    let adoptionCost = Adoption.calculateAdoptionCost(pig, state: nil)
    // Base adoption = 50, base sale value = 25 (for common)
    #expect(adoptionCost >= 50)
}
```

---

## 14. Stub Corrections

The Doc 01 stubs for Views files need the following corrections when implementing:

| File | Current Stub | Correction |
|------|-------------|------------|
| `StatusBarView.swift` | Empty `View` body | Full implementation per Section 3 |
| `ShopView.swift` | Empty `View` body | Full implementation per Section 4 |
| `PigListView.swift` | Empty `View` body | Full implementation per Section 5 |
| `PigDetailView.swift` | Empty `View` body | Full implementation per Section 6 |
| `BreedingView.swift` | Empty `View` body | Full implementation per Section 7 |
| `AlmanacView.swift` | Empty `View` body | Full implementation per Section 8 |
| `BiomeSelectView.swift` | Empty `View` body | Full implementation per Section 9 |
| `AdoptionView.swift` | Empty `View` body | Full implementation per Section 10 |
| `SharedComponents.swift` | Placeholder components | Full implementation per Section 11 |
| `ContentView.swift` | Placeholder body | Sheet wiring per Section 12 |

### New File Required

| File | Purpose |
|------|---------|
| `Economy/Adoption.swift` | Adoption logic functions (moved out of Views) |

---

## 15. Implementation Order

The recommended implementation order within Phase 4:

1. **SharedComponents** -- no dependencies, used by everything
2. **StatusBarView** -- simplest view, immediate visual feedback
3. **PigDetailView** -- standalone view used by PigListView
4. **PigListView** -- depends on PigDetailView for inline detail
5. **ShopView** (Facilities + Perks tabs) -- purchase flow
6. **BiomeSelectView** -- needed by ShopView Upgrades tab
7. **ShopView** (Upgrades tab) -- depends on BiomeSelectView
8. **AdoptionView** -- standalone then integrated as ShopView Adoption tab
9. **AlmanacView** -- three independent tabs
10. **BreedingView** -- most complex view, depends on genetics predictions
11. **ContentView updates** -- final wiring

---

## 16. What's Next

With all SwiftUI screens specified, the remaining work is:

1. **Doc 08 (Persistence & Polish):** Save/load system, app lifecycle, auto-save, haptic feedback, performance tuning, TestFlight preparation. Depends on all previous specs.
2. **Phase 4 Implementation:** Build the screens in the order specified in Section 15.
