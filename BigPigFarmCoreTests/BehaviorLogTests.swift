/// BehaviorLogTests — Tests for GuineaPig.behaviorLog and logBehavior().
import Foundation
import Testing
@testable import BigPigFarmCore

@MainActor
struct BehaviorLogTests {

    @Test("Fresh pig has empty behavior log")
    func testDefaultEmpty() {
        let pig = makePig()
        #expect(pig.behaviorLog.isEmpty)
    }

    @Test("logBehavior appends entry")
    func testAppend() {
        var pig = makePig()
        pig.logBehavior("Woke up (energy full)")
        #expect(pig.behaviorLog.count == 1)
        #expect(pig.behaviorLog[0] == "Woke up (energy full)")
    }

    @Test("logBehavior preserves insertion order")
    func testOrder() {
        var pig = makePig()
        pig.logBehavior("A")
        pig.logBehavior("B")
        pig.logBehavior("C")
        #expect(pig.behaviorLog == ["A", "B", "C"])
    }

    @Test("logBehavior caps at maxBehaviorLogEntries")
    func testCapping() {
        var pig = makePig()
        let max = GameConfig.Behavior.maxBehaviorLogEntries
        for i in 0..<(max + 10) {
            pig.logBehavior("Entry \(i)")
        }
        #expect(pig.behaviorLog.count == max)
        #expect(pig.behaviorLog.first == "Entry 10")
        #expect(pig.behaviorLog.last == "Entry \(max + 9)")
    }

    @Test("behaviorLog is not encoded in JSON")
    func testNotEncoded() throws {
        var pig = makePig()
        pig.logBehavior("Should not persist")
        pig.logBehavior("Another entry")
        let data = try JSONEncoder().encode(pig)
        let json = String(data: data, encoding: .utf8) ?? ""
        #expect(!json.contains("behaviorLog"))
        #expect(!json.contains("behavior_log"))
        #expect(!json.contains("Should not persist"))
    }

    @Test("behaviorLog defaults to empty on decode")
    func testDecodesEmpty() throws {
        var pig = makePig()
        pig.logBehavior("Will be lost on round-trip")
        let data = try JSONEncoder().encode(pig)
        let decoded = try JSONDecoder().decode(GuineaPig.self, from: data)
        #expect(decoded.behaviorLog.isEmpty)
    }

    @Test("JSON with extra behaviorLog key still decodes (forward compatibility)")
    func testForwardCompatibility() throws {
        // Encode a pig, then inject a behaviorLog key into the JSON.
        // The decoder should ignore the unknown key since it's not in CodingKeys.
        let pig = makePig()
        let data = try JSONEncoder().encode(pig)
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json["behavior_log"] = ["Injected entry"]
        let modifiedData = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(GuineaPig.self, from: modifiedData)
        #expect(decoded.id == pig.id)
        #expect(decoded.behaviorLog.isEmpty)
    }

    @Test("logBehavior keeps most recent entries when capped")
    func testKeepsMostRecent() {
        var pig = makePig()
        let max = GameConfig.Behavior.maxBehaviorLogEntries
        pig.logBehavior("Old entry")
        for i in 1...max {
            pig.logBehavior("New \(i)")
        }
        #expect(pig.behaviorLog.count == max)
        #expect(!pig.behaviorLog.contains("Old entry"))
        #expect(pig.behaviorLog.first == "New 1")
        #expect(pig.behaviorLog.last == "New \(max)")
    }
}
