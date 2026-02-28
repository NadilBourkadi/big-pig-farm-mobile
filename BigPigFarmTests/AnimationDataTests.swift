import Testing
@testable import BigPigFarm

// MARK: - Frame Count Lookups

@Test func walkingFrameCount() {
    #expect(AnimationData.frameCount(for: "walking") == 3)
}

@Test func eatingFrameCount() {
    #expect(AnimationData.frameCount(for: "eating") == 2)
}

@Test func sleepingFrameCount() {
    #expect(AnimationData.frameCount(for: "sleeping") == 2)
}

@Test func happyFrameCount() {
    #expect(AnimationData.frameCount(for: "happy") == 2)
}

@Test func idleFrameCountIsOne() {
    #expect(AnimationData.frameCount(for: "idle") == 1)
}

@Test func sadFrameCountIsOne() {
    #expect(AnimationData.frameCount(for: "sad") == 1)
}

@Test func unknownStateFrameCountDefaultsToOne() {
    #expect(AnimationData.frameCount(for: "nonexistent") == 1)
}

// MARK: - Ticks Per Frame Lookups

@Test func walkingTicksPerFrame() {
    #expect(AnimationData.ticksPerFrame["walking"] == 3)
}

@Test func eatingTicksPerFrame() {
    #expect(AnimationData.ticksPerFrame["eating"] == 4)
}

@Test func sleepingTicksPerFrame() {
    #expect(AnimationData.ticksPerFrame["sleeping"] == 10)
}

@Test func happyTicksPerFrame() {
    #expect(AnimationData.ticksPerFrame["happy"] == 3)
}

@Test func idleTicksPerFrameIsNil() {
    #expect(AnimationData.ticksPerFrame["idle"] == nil)
}

@Test func sadTicksPerFrameIsNil() {
    #expect(AnimationData.ticksPerFrame["sad"] == nil)
}

@Test func unknownStateTicksPerFrameIsNil() {
    #expect(AnimationData.ticksPerFrame["nonexistent"] == nil)
}

@Test func ticksPerFrameValueLookup() {
    #expect(AnimationData.ticksPerFrameValue(for: "walking") == 3)
    #expect(AnimationData.ticksPerFrameValue(for: "idle") == nil)
    #expect(AnimationData.ticksPerFrameValue(for: "nonexistent") == nil)
}

// MARK: - Cycle Duration

@Test func walkingCycleDuration() {
    // 3 ticks/frame * 3 frames = 9
    #expect(AnimationData.cycleDuration(for: "walking") == 9)
}

@Test func eatingCycleDuration() {
    // 4 ticks/frame * 2 frames = 8
    #expect(AnimationData.cycleDuration(for: "eating") == 8)
}

@Test func sleepingCycleDuration() {
    // 10 ticks/frame * 2 frames = 20
    #expect(AnimationData.cycleDuration(for: "sleeping") == 20)
}

@Test func happyCycleDuration() {
    // 3 ticks/frame * 2 frames = 6
    #expect(AnimationData.cycleDuration(for: "happy") == 6)
}

@Test func idleCycleDurationIsNil() {
    #expect(AnimationData.cycleDuration(for: "idle") == nil)
}

@Test func sadCycleDurationIsNil() {
    #expect(AnimationData.cycleDuration(for: "sad") == nil)
}

@Test func unknownStateCycleDurationIsNil() {
    #expect(AnimationData.cycleDuration(for: "nonexistent") == nil)
}

// MARK: - State Classification

@Test func animatedStatesContainsAllAnimatedStates() {
    #expect(AnimationData.animatedStates.contains("walking"))
    #expect(AnimationData.animatedStates.contains("eating"))
    #expect(AnimationData.animatedStates.contains("happy"))
    #expect(AnimationData.animatedStates.contains("sleeping"))
    #expect(AnimationData.animatedStates.count == 4)
}

@Test func staticStatesContainsIdleAndSad() {
    #expect(AnimationData.staticStates.contains("idle"))
    #expect(AnimationData.staticStates.contains("sad"))
    #expect(AnimationData.staticStates.count == 2)
}

@Test func animatedAndStaticSetsAreDisjoint() {
    #expect(AnimationData.animatedStates.isDisjoint(with: AnimationData.staticStates))
}

// MARK: - Baby Fallback

@Test func babyFallbackIdleStaysIdle() {
    #expect(AnimationData.babyFallbackState(for: "idle") == "idle")
}

@Test func babyFallbackWalkingStaysWalking() {
    #expect(AnimationData.babyFallbackState(for: "walking") == "walking")
}

@Test func babyFallbackSleepingStaysSleeping() {
    #expect(AnimationData.babyFallbackState(for: "sleeping") == "sleeping")
}

@Test func babyFallbackEatingFallsBackToIdle() {
    #expect(AnimationData.babyFallbackState(for: "eating") == "idle")
}

@Test func babyFallbackHappyFallsBackToIdle() {
    #expect(AnimationData.babyFallbackState(for: "happy") == "idle")
}

@Test func babyFallbackSadFallsBackToIdle() {
    #expect(AnimationData.babyFallbackState(for: "sad") == "idle")
}

@Test func babyFallbackUnknownStatePassesThrough() {
    #expect(AnimationData.babyFallbackState(for: "nonexistent") == "nonexistent")
}

// MARK: - Consistency Invariants

@Test func ticksPerFrameAndFrameCountsHaveSameKeys() {
    let tpfKeys = Set(AnimationData.ticksPerFrame.keys)
    let fcKeys = Set(AnimationData.frameCounts.keys)
    #expect(tpfKeys == fcKeys, "ticksPerFrame and frameCounts must have identical key sets")
}

@Test func allFrameCountsArePositive() {
    for (state, count) in AnimationData.frameCounts {
        #expect(count > 0, "\(state) has non-positive frame count: \(count)")
    }
}

@Test func allTicksPerFrameArePositive() {
    for (state, tpf) in AnimationData.ticksPerFrame {
        #expect(tpf > 0, "\(state) has non-positive ticks-per-frame: \(tpf)")
    }
}

@Test func cycleDurationMatchesProduct() {
    for state in AnimationData.animatedStates {
        let tpf = AnimationData.ticksPerFrame[state]!
        let fc = AnimationData.frameCounts[state]!
        #expect(AnimationData.cycleDuration(for: state) == tpf * fc)
    }
}
