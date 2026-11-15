/// Normalized joint positions with y pointing up, as Vision reports them.
nonisolated struct HandJoints: Equatable, Sendable {
    var wrist: HandPoint
    var thumbTip: HandPoint
    var thumbIP: HandPoint
    var thumbMP: HandPoint
    var fingerTips: [HandPoint]
    var fingerKnuckles: [HandPoint]
}
