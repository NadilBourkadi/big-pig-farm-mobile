/// Pixel coordinate maps for pattern application.
///
/// Source: big_pig_farm/data/pig_sprites.py — PIG_PIXELS_ADULT/BABY["idle_right"]
/// Coordinate convention: GridPosition(x: column, y: row), origin top-left.
/// Adult sprites: 14×8 art pixels. Baby sprites: 8×6 art pixels.
///
/// "Inner fur" = fur pixels where all 4 cardinal neighbors are body pixels
/// (fur, nose, eye, pupil, belly, paw, tooth, ear, blush, tear).
/// Edge fur adjacent to dark outline or transparency is excluded.
enum SpriteFurMaps {

    // MARK: - Adult (14×8)

    /// All fur pixels for adult pig sprites (14×8).
    /// Used by Himalayan intensity (all fur except ears become belly color).
    static let adultAllFur: Set<GridPosition> = [
        // Row 1
        GridPosition(x: 8, y: 1), GridPosition(x: 9, y: 1),
        GridPosition(x: 10, y: 1), GridPosition(x: 11, y: 1),
        // Row 2
        GridPosition(x: 4, y: 2), GridPosition(x: 5, y: 2),
        GridPosition(x: 6, y: 2), GridPosition(x: 7, y: 2),
        GridPosition(x: 8, y: 2), GridPosition(x: 12, y: 2),
        // Row 3
        GridPosition(x: 2, y: 3), GridPosition(x: 3, y: 3),
        GridPosition(x: 4, y: 3), GridPosition(x: 5, y: 3),
        GridPosition(x: 6, y: 3), GridPosition(x: 7, y: 3),
        GridPosition(x: 8, y: 3),
        // Row 4
        GridPosition(x: 1, y: 4), GridPosition(x: 2, y: 4),
        GridPosition(x: 3, y: 4), GridPosition(x: 4, y: 4),
        GridPosition(x: 5, y: 4), GridPosition(x: 6, y: 4),
        GridPosition(x: 7, y: 4), GridPosition(x: 8, y: 4),
        GridPosition(x: 9, y: 4), GridPosition(x: 10, y: 4),
        GridPosition(x: 11, y: 4), GridPosition(x: 12, y: 4),
        // Row 5
        GridPosition(x: 3, y: 5), GridPosition(x: 4, y: 5),
        GridPosition(x: 5, y: 5), GridPosition(x: 6, y: 5),
        GridPosition(x: 7, y: 5), GridPosition(x: 8, y: 5),
        GridPosition(x: 9, y: 5), GridPosition(x: 10, y: 5),
    ]

    /// Inner fur pixels for adult pig sprites (14×8).
    /// Fur pixels where all 4 cardinal neighbors are also body pixels.
    /// Used by Dalmatian spots, Chinchilla ticking, and Roan scatter.
    static let adultInnerFur: Set<GridPosition> = [
        // Row 1 — only x=10 has all 4 neighbors as body pixels
        GridPosition(x: 10, y: 1),
        // Row 2 — only x=8 qualifies (right neighbor is "eye")
        GridPosition(x: 8, y: 2),
        // Row 3
        GridPosition(x: 4, y: 3), GridPosition(x: 5, y: 3),
        GridPosition(x: 6, y: 3), GridPosition(x: 7, y: 3),
        GridPosition(x: 8, y: 3),
        // Row 4
        GridPosition(x: 2, y: 4), GridPosition(x: 3, y: 4),
        GridPosition(x: 4, y: 4), GridPosition(x: 5, y: 4),
        GridPosition(x: 6, y: 4), GridPosition(x: 7, y: 4),
        GridPosition(x: 8, y: 4), GridPosition(x: 9, y: 4),
        GridPosition(x: 10, y: 4), GridPosition(x: 11, y: 4),
        // Row 5
        GridPosition(x: 3, y: 5), GridPosition(x: 4, y: 5),
        GridPosition(x: 5, y: 5), GridPosition(x: 6, y: 5),
        GridPosition(x: 7, y: 5), GridPosition(x: 8, y: 5),
        GridPosition(x: 9, y: 5), GridPosition(x: 10, y: 5),
    ]

    /// Ear pixels for adult pig sprites (14×8).
    /// Excluded from Himalayan intensity lightening.
    static let adultEarPixels: Set<GridPosition> = [
        GridPosition(x: 10, y: 0),
    ]

    // MARK: - Baby (8×6)

    /// All fur pixels for baby pig sprites (8×6).
    static let babyAllFur: Set<GridPosition> = [
        // Row 1
        GridPosition(x: 4, y: 1), GridPosition(x: 5, y: 1), GridPosition(x: 6, y: 1),
        // Row 2
        GridPosition(x: 2, y: 2), GridPosition(x: 3, y: 2), GridPosition(x: 6, y: 2),
        // Row 3
        GridPosition(x: 2, y: 3), GridPosition(x: 3, y: 3),
    ]

    /// Inner fur pixels for baby pig sprites (8×6).
    /// Fur pixels where all 4 cardinal neighbors are also body pixels.
    static let babyInnerFur: Set<GridPosition> = [
        // Row 1: x=5 only — up=(5,0)="ear", down=(5,2)="pupil", left=(4,1)="fur", right=(6,1)="fur"
        GridPosition(x: 5, y: 1),
        // Row 3: both qualify — neighbors include fur, belly, eye
        GridPosition(x: 2, y: 3), GridPosition(x: 3, y: 3),
    ]

    /// Ear pixels for baby pig sprites (8×6).
    static let babyEarPixels: Set<GridPosition> = [
        GridPosition(x: 5, y: 0),
    ]
}
