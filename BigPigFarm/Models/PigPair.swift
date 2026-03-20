/// PigPair — Canonically ordered UUID pair for O(1) hash-based deduplication.
///
/// Replaces string-concatenation dedup in `SpatialGrid.uniqueNearbyPairs`,
/// eliminating per-pair String allocations. UUID's synthesized `Hashable`
/// hashes the raw 128-bit value — no string conversion needed.
import Foundation

struct PigPair: Hashable, Sendable {
    let low: UUID
    let high: UUID

    /// Create a canonically ordered pair. `PigPair(id1, id2) == PigPair(id2, id1)` for any UUIDs.
    init(_ id1: UUID, _ id2: UUID) {
        let firstIsLess = withUnsafeBytes(of: id1.uuid) { buf1 in
            withUnsafeBytes(of: id2.uuid) { buf2 in
                buf1.lexicographicallyPrecedes(buf2)
            }
        }
        if firstIsLess {
            low = id1; high = id2
        } else {
            low = id2; high = id1
        }
    }
}
