/// PigPairTests — Validate canonical ordering and Set-based deduplication.
@testable import BigPigFarmCore
import Foundation
import Testing

struct PigPairTests {

    @Test func canonicalOrderingIsDeterministic() {
        let a = UUID()
        let b = UUID()
        let pair1 = PigPair(a, b)
        let pair2 = PigPair(b, a)
        #expect(pair1 == pair2)
        #expect(pair1.low == pair2.low)
        #expect(pair1.high == pair2.high)
    }

    @Test func identityPairHasSameLowAndHigh() {
        let a = UUID()
        let pair = PigPair(a, a)
        #expect(pair.low == a)
        #expect(pair.high == a)
    }

    @Test func setDeduplicatesBothOrderings() {
        let a = UUID()
        let b = UUID()
        var set = Set<PigPair>()
        set.insert(PigPair(a, b))
        set.insert(PigPair(b, a))
        #expect(set.count == 1)
    }

    @Test func distinctPairsAreNotEqual() {
        let a = UUID()
        let b = UUID()
        let c = UUID()
        #expect(PigPair(a, b) != PigPair(a, c))
        #expect(PigPair(a, b) != PigPair(b, c))
    }

    @Test func hashValuesMatchForBothOrderings() {
        let a = UUID()
        let b = UUID()
        #expect(PigPair(a, b).hashValue == PigPair(b, a).hashValue)
    }
}
