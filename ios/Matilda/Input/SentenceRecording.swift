import Foundation

/// Collects frames while Ray mouths a sentence and decides when he has finished.
nonisolated struct SentenceRecording: Sendable {
    var startThreshold: Float = 0.12
    var stopThreshold: Float = 0.07
    /// How long the lips must rest after speaking before the sentence counts as done.
    var restToFinish: TimeInterval = 1.5
    var maximumDuration: TimeInterval = 12

    private(set) var frames: [(time: TimeInterval, jpeg: Data)] = []
    private var startedAt: TimeInterval?
    private var lastActive: TimeInterval?
    private var finished = false

    var lipsMoving = false

    mutating func append(_ jpeg: Data, at time: TimeInterval) {
        frames.append((time, jpeg))
    }

    /// Feeds one face-tracking sample. Returns true exactly once, when the sentence is complete.
    mutating func feed(_ features: [Float], at time: TimeInterval) -> Bool {
        if startedAt == nil { startedAt = time }
        let energy = features.reduce(0, +) / Float(max(features.count, 1))
        if energy > startThreshold || (lastActive != nil && energy >= stopThreshold) { lastActive = time }
        lipsMoving = lastActive.map { time - $0 < 0.25 } ?? false

        guard !finished, let startedAt else { return false }
        let rested = lastActive.map { time - $0 >= restToFinish } ?? false
        if rested || time - startedAt >= maximumDuration {
            finished = true
            return true
        }
        return false
    }

    /// The frames from just before the first movement to just after the last, or nil if nothing was said.
    func clip(padding: TimeInterval = 0.3) -> LipClip? {
        guard let lastActive else { return nil }
        let firstMove = frames.first?.time ?? lastActive
        let selected = frames.filter { $0.time >= firstMove - padding && $0.time <= lastActive + padding }
        guard selected.count >= 8, let first = selected.first, let last = selected.last, last.time > first.time else {
            return nil
        }
        return LipClip(frames: selected.map(\.jpeg), fps: Double(selected.count - 1) / (last.time - first.time))
    }
}
