/// BatchUpdateTests — Validate cache suppression during batch updates.
@testable import BigPigFarmCore
import Foundation
import Testing

@MainActor
struct BatchUpdateTests {

    // MARK: - Helpers

    private func makeState() -> GameState {
        GameState()
    }

    private func makePig(name: String = "Test") -> GuineaPig {
        var pig = GuineaPig.create(name: name, gender: .female)
        pig.position = Position(x: 5, y: 5)
        return pig
    }

    // MARK: - Basic Batch Behavior

    @Test func updateInsideBatchDoesNotRebuildCache() {
        let state = makeState()
        var pig = makePig()
        state.addGuineaPig(pig)

        // Prime the cache
        _ = state.getPigsList()

        state.beginBatchUpdate()
        pig.position.x = 10
        state.updateGuineaPig(pig)

        // Cache should still be stale (original position) during batch
        let listDuringBatch = state.getPigsList()
        #expect(listDuringBatch.first?.position.x == 5)

        state.endBatchUpdate()

        // After batch ends, cache is invalidated — fresh read sees the update
        let listAfterBatch = state.getPigsList()
        #expect(listAfterBatch.first?.position.x == 10)
    }

    @Test func withBatchUpdateInvalidatesOnExit() {
        let state = makeState()
        var pig = makePig()
        state.addGuineaPig(pig)
        _ = state.getPigsList()

        state.withBatchUpdate {
            pig.position.x = 20
            state.updateGuineaPig(pig)
        }

        let list = state.getPigsList()
        #expect(list.first?.position.x == 20)
    }

    // MARK: - Nested Batches

    @Test func nestedBatchOnlyInvalidatesOnOutermostEnd() {
        let state = makeState()
        var pig = makePig()
        state.addGuineaPig(pig)
        _ = state.getPigsList()

        state.beginBatchUpdate()
        state.beginBatchUpdate()

        pig.position.x = 30
        state.updateGuineaPig(pig)

        state.endBatchUpdate()
        // Inner batch ended — cache should still be stale
        let midList = state.getPigsList()
        #expect(midList.first?.position.x == 5)

        state.endBatchUpdate()
        // Outer batch ended — cache invalidated
        let finalList = state.getPigsList()
        #expect(finalList.first?.position.x == 30)
    }

    // MARK: - Add/Remove During Batch

    @Test func addDuringBatchVisibleAfterEnd() {
        let state = makeState()
        let pig1 = makePig(name: "First")
        state.addGuineaPig(pig1)
        _ = state.getPigsList()

        let pig2 = makePig(name: "Second")
        state.withBatchUpdate {
            state.addGuineaPig(pig2)
        }

        let list = state.getPigsList()
        #expect(list.count == 2)
    }

    @Test func removeDuringBatchVisibleAfterEnd() {
        let state = makeState()
        let pig = makePig()
        state.addGuineaPig(pig)
        _ = state.getPigsList()

        state.withBatchUpdate {
            _ = state.removeGuineaPig(pig.id)
        }

        let list = state.getPigsList()
        #expect(list.isEmpty)
    }

    // MARK: - Zero-Change Batch

    @Test func emptyBatchDoesNotCrash() {
        let state = makeState()
        let pig = makePig()
        state.addGuineaPig(pig)
        _ = state.getPigsList()

        state.withBatchUpdate { }

        let list = state.getPigsList()
        #expect(list.count == 1)
    }

    // MARK: - Direct Dictionary Access During Batch

    @Test func getGuineaPigSeesUpdatesInsideBatch() {
        let state = makeState()
        var pig = makePig()
        state.addGuineaPig(pig)

        state.beginBatchUpdate()
        pig.position.x = 42
        state.updateGuineaPig(pig)

        // Direct dictionary lookup should see the update immediately
        let fetched = state.getGuineaPig(pig.id)
        #expect(fetched?.position.x == 42)

        state.endBatchUpdate()
    }
}
