nonisolated enum ThumbClassifier {
    /// A thumb counts as up or down when it is extended, points mostly vertically,
    /// and the other four fingers are curled toward the palm.
    static func classify(_ hand: HandJoints) -> ThumbPose {
        let thumbLength = hand.thumbTip.distance(to: hand.thumbMP)
        let palmSize = hand.fingerKnuckles.map { $0.distance(to: hand.wrist) }.reduce(0, +)
            / Double(max(hand.fingerKnuckles.count, 1))
        guard palmSize > 0, thumbLength > palmSize * 0.45 else { return .none }

        let dx = hand.thumbTip.x - hand.thumbMP.x
        let dy = hand.thumbTip.y - hand.thumbMP.y
        guard abs(dy) > abs(dx) * 1.2 else { return .none }

        let curled = zip(hand.fingerTips, hand.fingerKnuckles).allSatisfy { tip, knuckle in
            tip.distance(to: hand.wrist) < knuckle.distance(to: hand.wrist) * 1.25
        }
        guard curled else { return .none }

        let ordered = dy > 0
            ? hand.thumbTip.y > hand.thumbIP.y && hand.thumbIP.y > hand.thumbMP.y
            : hand.thumbTip.y < hand.thumbIP.y && hand.thumbIP.y < hand.thumbMP.y
        guard ordered else { return .none }
        return dy > 0 ? .up : .down
    }
}
