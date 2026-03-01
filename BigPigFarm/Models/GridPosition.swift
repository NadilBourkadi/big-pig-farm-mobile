/// GridPosition -- Integer grid coordinate, replacing Python's tuple[int, int].
/// New type for Swift compatibility (tuples are not Codable).
import Foundation

struct GridPosition: Codable, Sendable, Hashable {
    let x: Int
    let y: Int

    /// Manhattan distance to another grid position.
    func manhattanDistance(to other: Self) -> Int {
        abs(x - other.x) + abs(y - other.y)
    }
}
