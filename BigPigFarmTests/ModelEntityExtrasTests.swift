/// ModelEntityExtrasTests — Tests for Pigdex, Cell, GameTime, Currency,
/// BreedingProgram, ContractBoard, TunnelConnection, and Sendable conformance.
/// Split from ModelEntityTests.swift to stay under 300 lines.
import Testing
import Foundation
@testable import BigPigFarm

// MARK: - Pigdex Tests

@Test func pigdexRegisterNew() {
    var pigdex = Pigdex()
    let isNew = pigdex.registerPhenotype(key: "black:solid:full:none", gameDay: 1)
    #expect(isNew)
    #expect(pigdex.discoveredCount == 1)
}

@Test func pigdexRegisterDuplicate() {
    var pigdex = Pigdex()
    _ = pigdex.registerPhenotype(key: "black:solid:full:none", gameDay: 1)
    let isNew = pigdex.registerPhenotype(key: "black:solid:full:none", gameDay: 2)
    #expect(!isNew)
    #expect(pigdex.discoveredCount == 1)
}

@Test func pigdexMilestones() {
    var pigdex = Pigdex()
    // Register 36 phenotypes (25% of 144)
    for i in 0..<36 {
        _ = pigdex.registerPhenotype(key: "key_\(i)", gameDay: 1)
    }
    let milestones = pigdex.checkMilestones()
    #expect(milestones.contains(25))
}

@Test func pigdexCompletionPercent() {
    var pigdex = Pigdex()
    _ = pigdex.registerPhenotype(key: "test", gameDay: 1)
    let expected = (1.0 / 144.0) * 100
    #expect(abs(pigdex.completionPercent - expected) < 0.01)
}

@Test func phenotypeKeyRoundTrip() {
    let phenotype = Phenotype(
        baseColor: .chocolate, pattern: .dutch,
        intensity: .chinchilla, roan: .roan, rarity: .legendary
    )
    let key = phenotypeKey(phenotype)
    #expect(key == "chocolate:dutch:chinchilla:roan")
}

@Test func getAllPhenotypeKeysCount() {
    let keys = getAllPhenotypeKeys()
    #expect(keys.count == 144)
}

// MARK: - Cell Tests

@Test func cellDefaultValues() {
    let cell = Cell()
    #expect(cell.cellType == .floor)
    #expect(cell.facilityId == nil)
    #expect(cell.isWalkable)
    #expect(!cell.isTunnel)
    #expect(!cell.isCorner)
}

@Test func cellCodable() throws {
    let cell = Cell(cellType: .wall, isWalkable: false, isCorner: true)
    let data = try JSONEncoder().encode(cell)
    let decoded = try JSONDecoder().decode(Cell.self, from: data)
    #expect(decoded.cellType == .wall)
    #expect(!decoded.isWalkable)
    #expect(decoded.isCorner)
}

// MARK: - GameTime Tests

@Test func gameTimeAdvance() {
    var time = GameTime()
    time.advance(minutes: 90)
    #expect(time.hour == 9)    // 8 + 1
    #expect(time.minute == 30) // 0 + 30
}

@Test func gameTimeAdvanceNewDay() {
    var time = GameTime(day: 1, hour: 23, minute: 30)
    time.advance(minutes: 60)
    #expect(time.day == 2)
    #expect(time.hour == 0)
    #expect(time.minute == 30)
}

@Test func gameTimeIsDaytime() {
    let morning = GameTime(hour: 8)
    #expect(morning.isDaytime)

    let night = GameTime(hour: 22)
    #expect(!night.isDaytime)
}

@Test func gameTimeDisplayTime() {
    let time = GameTime(day: 3, hour: 14, minute: 5)
    #expect(time.displayTime == "Day 3 14:05")
}

// MARK: - Currency Tests

@Test func currencyFormatMoney() {
    #expect(Currency.formatMoney(500) == "500")
    #expect(Currency.formatMoney(1500) == "1.5K")
    #expect(Currency.formatMoney(2500000) == "2.5M")
}

@Test func currencyFormatCurrency() {
    #expect(Currency.formatCurrency(1500) == "Sq1.5K")
}

// MARK: - BreedingProgram Tests

@Test func breedingProgramHasTarget() {
    var program = BreedingProgram()
    #expect(!program.hasTarget)
    program.targetColors.insert(.black)
    #expect(program.hasTarget)
}

@Test func breedingProgramShouldAutoPair() {
    var program = BreedingProgram()
    #expect(!program.shouldAutoPair())
    program.enabled = true
    program.autoPair = true
    #expect(program.shouldAutoPair())
}

@Test func breedingProgramCodable() throws {
    var program = BreedingProgram()
    program.targetColors = [.black, .chocolate]
    program.strategy = .diversity
    program.enabled = true
    let data = try JSONEncoder().encode(program)
    let decoded = try JSONDecoder().decode(BreedingProgram.self, from: data)
    #expect(decoded.targetColors == [.black, .chocolate])
    #expect(decoded.strategy == .diversity)
    #expect(decoded.enabled)
}

// MARK: - ContractBoard Tests

@Test func contractBoardRemoveFulfilled() {
    var board = ContractBoard()
    board.activeContracts = [
        BreedingContract(requiredColor: .black, fulfilled: true),
        BreedingContract(requiredColor: .golden, fulfilled: false),
    ]
    board.removeFulfilled()
    #expect(board.activeContracts.count == 1)
    #expect(board.activeContracts[0].requiredColor == .golden)
}

@Test func contractBoardCheckExpiry() {
    var board = ContractBoard()
    board.activeContracts = [
        BreedingContract(requiredColor: .black, deadlineDay: 5),
        BreedingContract(requiredColor: .golden, deadlineDay: 20),
    ]
    let expired = board.checkExpiry(gameDay: 10)
    #expect(expired.count == 1)
    #expect(board.activeContracts.count == 1)
}

@Test func contractBoardNeedsRefresh() {
    let board = ContractBoard(lastRefreshDay: 1)
    #expect(board.needsRefresh(gameDay: 15))
    #expect(!board.needsRefresh(gameDay: 5))
}

// MARK: - TunnelConnection Tests

@Test func tunnelConnectionCodable() throws {
    let tunnel = TunnelConnection(
        id: UUID(),
        areaAId: UUID(),
        areaBId: UUID(),
        cells: [GridPosition(x: 5, y: 10), GridPosition(x: 6, y: 10)]
    )
    let data = try JSONEncoder().encode(tunnel)
    let decoded = try JSONDecoder().decode(TunnelConnection.self, from: data)
    #expect(decoded.id == tunnel.id)
    #expect(decoded.cells.count == 2)
}

// MARK: - Sendable Conformance

@Test func allStructsAreSendable() {
    // Compile-time verification of Sendable conformance
    let _: any Sendable = AllelePair(first: "E", second: "e")
    let _: any Sendable = GridPosition(x: 0, y: 0)
    let _: any Sendable = Position()
    let _: any Sendable = Needs()
    let _: any Sendable = Genotype.randomCommon()
    let _: any Sendable = Phenotype(baseColor: .black, pattern: .solid, intensity: .full, roan: .none, rarity: .common)
    let _: any Sendable = FacilitySize(width: 1, height: 1)
    let _: any Sendable = Facility.create(type: .foodBowl, x: 0, y: 0)
    let _: any Sendable = FarmArea(id: UUID(), name: "Test", biome: .meadow, x1: 0, y1: 0, x2: 10, y2: 10)
    let _: any Sendable = TunnelConnection(id: UUID(), areaAId: UUID(), areaBId: UUID())
    let _: any Sendable = Pigdex()
    let _: any Sendable = GameTime()
    let _: any Sendable = EventLog(timestamp: Date(), gameDay: 1, message: "Test", eventType: "info")
    let _: any Sendable = BreedingPair(maleId: UUID(), femaleId: UUID())
    let _: any Sendable = Cell()
    let _: any Sendable = BreedingContract()
    let _: any Sendable = ContractBoard()
    let _: any Sendable = BreedingProgram()
    let _: any Sendable = SaleResult(baseValue: 100, contractBonus: 0, matchedContract: nil)
}
