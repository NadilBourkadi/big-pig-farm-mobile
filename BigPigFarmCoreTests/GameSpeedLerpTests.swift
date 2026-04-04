/// GameSpeedLerpTests — Verifies movementLerpFactor values and invariants.
import Testing
@testable import BigPigFarmCore

@Suite("GameSpeed movementLerpFactor")
struct GameSpeedLerpTests {

    @Test("Normal speed preserves original 0.25 factor")
    func normalSpeedFactor() {
        #expect(GameSpeed.normal.movementLerpFactor == 0.25)
    }

    @Test("Paused speed snaps instantly")
    func pausedSpeedSnaps() {
        #expect(GameSpeed.paused.movementLerpFactor == 1.0)
    }

    @Test("Fast speed uses intermediate factor")
    func fastSpeedFactor() {
        #expect(GameSpeed.fast.movementLerpFactor == 0.5)
    }

    @Test("Faster speed uses high factor")
    func fasterSpeedFactor() {
        #expect(GameSpeed.faster.movementLerpFactor == 0.8)
    }

    @Test("Fastest and debug speeds snap instantly")
    func highSpeedsSnap() {
        #expect(GameSpeed.fastest.movementLerpFactor == 1.0)
        #expect(GameSpeed.debug.movementLerpFactor == 1.0)
        #expect(GameSpeed.debugFast.movementLerpFactor == 1.0)
    }

    @Test("All factors are in 0...1 range")
    func allFactorsInUnitRange() {
        for speed in GameSpeed.allCases {
            #expect(speed.movementLerpFactor >= 0 && speed.movementLerpFactor <= 1,
                    "\(speed) has out-of-range factor \(speed.movementLerpFactor)")
        }
    }

    @Test("Factor increases monotonically with speed (excluding paused)")
    func factorIncreasesWithSpeed() {
        let speeds: [GameSpeed] = [.normal, .fast, .faster, .fastest, .debug, .debugFast]
        for i in 0..<(speeds.count - 1) {
            #expect(speeds[i].movementLerpFactor <= speeds[i + 1].movementLerpFactor,
                    "\(speeds[i]) factor should be <= \(speeds[i + 1]) factor")
        }
    }
}
