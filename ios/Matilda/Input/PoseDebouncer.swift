import Foundation

/// Requires a pose to hold for most of a short window before it fires. The same pose cannot fire again
/// until the hand has rested and the cooldown has passed, so a held thumb never approves the next question.
/// The opposite pose fires right away, so a thumbs down can still stop an answer that is about to be said.
nonisolated struct PoseDebouncer<Pose: Equatable & Sendable>: Sendable {
    let window: Int
    let required: Int
    let cooldown: TimeInterval
    let idle: Pose

    private var recent: [Pose] = []
    private var lastFired: TimeInterval = -.infinity
    private var lastPose: Pose?
    private var rested = true
    private var idleRun = 0
    private let restSamples = 4

    init(window: Int = 12, required: Int = 8, cooldown: TimeInterval = 1.5, idle: Pose) {
        self.window = window
        self.required = required
        self.cooldown = cooldown
        self.idle = idle
    }

    mutating func feed(_ pose: Pose, at time: TimeInterval) -> Pose? {
        recent.append(pose)
        if recent.count > window { recent.removeFirst(recent.count - window) }
        if pose == idle {
            idleRun += 1
            if idleRun >= restSamples { rested = true }
            return nil
        }
        idleRun = 0
        if pose == lastPose, !rested || time - lastFired < cooldown { return nil }
        guard recent.count(where: { $0 == pose }) >= required else { return nil }
        lastFired = time
        lastPose = pose
        rested = false
        recent.removeAll()
        return pose
    }
}
