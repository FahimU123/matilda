import Testing
@testable import Matilda

struct ThumbClassifierTests {
    func hand(thumbPointing direction: Double, fingersCurled: Bool = true) -> HandJoints {
        let wrist = HandPoint(x: 0.5, y: 0.3)
        let knuckles = (0..<4).map { HandPoint(x: 0.42 + Double($0) * 0.05, y: 0.45) }
        let tips = knuckles.map { HandPoint(x: $0.x, y: fingersCurled ? 0.40 : 0.65) }
        return HandJoints(
            wrist: wrist,
            thumbTip: HandPoint(x: 0.36, y: 0.45 + direction * 0.16),
            thumbIP: HandPoint(x: 0.36, y: 0.45 + direction * 0.08),
            thumbMP: HandPoint(x: 0.37, y: 0.45),
            fingerTips: tips,
            fingerKnuckles: knuckles
        )
    }

    @Test(arguments: [(1.0, ThumbPose.up), (-1.0, ThumbPose.down)])
    func detectsVerticalThumb(direction: Double, expected: ThumbPose) {
        #expect(ThumbClassifier.classify(hand(thumbPointing: direction)) == expected)
    }

    @Test func openHandIsNotAThumbsUp() {
        #expect(ThumbClassifier.classify(hand(thumbPointing: 1, fingersCurled: false)) == .none)
    }

    @Test func debouncerNeedsTheGestureToHold() {
        var debouncer = PoseDebouncer<ThumbPose>(window: 5, required: 3, cooldown: 1, idle: .none)
        #expect(debouncer.feed(.up, at: 0.0) == nil)
        #expect(debouncer.feed(.none, at: 0.1) == nil)
        #expect(debouncer.feed(.up, at: 0.2) == nil)
        #expect(debouncer.feed(.up, at: 0.3) == .up)
        #expect(debouncer.feed(.up, at: 0.4) == nil)
    }

    @Test func aHeldThumbDoesNotApproveTheNextQuestion() {
        var debouncer = PoseDebouncer<ThumbPose>(window: 5, required: 3, cooldown: 1, idle: .none)
        var fired: [ThumbPose] = []
        for step in 0..<80 {
            if let pose = debouncer.feed(.up, at: Double(step) * 0.05) { fired.append(pose) }
        }
        #expect(fired == [.up])
    }

    @Test func thumbsDownRightAfterThumbsUpStillStops() {
        var debouncer = PoseDebouncer<ThumbPose>(window: 5, required: 3, cooldown: 1.5, idle: .none)
        for step in 0..<3 { _ = debouncer.feed(.up, at: Double(step) * 0.05) }
        var stopped: ThumbPose?
        for step in 3..<8 { stopped = debouncer.feed(.down, at: Double(step) * 0.05) ?? stopped }
        #expect(stopped == .down)
    }

    @Test func theSameGestureWorksAgainAfterTheHandRests() {
        var debouncer = PoseDebouncer<ThumbPose>(window: 5, required: 3, cooldown: 0.5, idle: .none)
        for step in 0..<3 { _ = debouncer.feed(.up, at: Double(step) * 0.05) }
        for step in 3..<10 { _ = debouncer.feed(.none, at: Double(step) * 0.05) }
        var again: ThumbPose?
        for step in 20..<24 { again = debouncer.feed(.up, at: Double(step) * 0.05) ?? again }
        #expect(again == .up)
    }
}
