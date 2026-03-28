/// PigDetailViewModel — Domain lookups for PigDetailView.
/// Maps from: ui/screens/pig_detail.py
import Foundation

@MainActor @Observable
final class PigDetailViewModel {

    let gameState: GameState
    let pig: GuineaPig

    init(gameState: GameState, pig: GuineaPig) {
        self.gameState = gameState
        self.pig = pig
    }

    // MARK: - Basic Info

    var valueBreakdown: PigValueBreakdown {
        Market.calculatePigValueBreakdown(pig: pig, state: gameState)
    }

    var hasGeneticsLab: Bool {
        !gameState.getFacilitiesByType(.geneticsLab).isEmpty
    }

    var ageDescription: String {
        let days = Int(pig.ageDays)
        switch pig.ageGroup {
        case .baby: return "\(days)d (Baby)"
        case .adult: return "\(days)d (Adult)"
        case .senior: return "\(days)d (Senior)"
        }
    }

    var areaName: String {
        guard let id = pig.currentAreaId,
              let area = gameState.farm.getAreaByID(id) else { return "Unknown" }
        return area.name
    }

    var birthAreaName: String {
        guard let id = pig.birthAreaId,
              let area = gameState.farm.getAreaByID(id) else { return "Unknown" }
        return area.name
    }

    func parentName(id: UUID?) -> String {
        guard let id else { return "Unknown (adopted/starter)" }
        if let parent = gameState.getGuineaPig(id) { return parent.name }
        return "Unknown (no longer on farm)"
    }

    // MARK: - Live Data

    /// Read the behavior log live from gameState so it updates in real-time.
    var liveLog: [String] {
        gameState.getGuineaPig(pig.id)?.behaviorLog ?? pig.behaviorLog
    }
}
