import Foundation

/// Finds where a word was mouthed by watching how much the lips and jaw move between pauses.
nonisolated struct MouthSegmenter: Sendable {
    var startThreshold: Float = 0.12
    var stopThreshold: Float = 0.07
    var minimumDuration: TimeInterval = 0.15
    var silence: TimeInterval = 0.3
    var maximumDuration: TimeInterval = 3

    private var start: TimeInterval?
    private var lastActive: TimeInterval = 0

    mutating func feed(_ frame: [Float], at time: TimeInterval) -> MouthedWord? {
        let energy = frame.reduce(0, +) / Float(max(frame.count, 1))
        guard let started = start else {
            if energy > startThreshold {
                start = time
                lastActive = time
            }
            return nil
        }

        if energy >= stopThreshold { lastActive = time }
        let quietFor = time - lastActive
        guard quietFor >= silence || time - started >= maximumDuration else { return nil }

        start = nil
        return lastActive - started >= minimumDuration ? MouthedWord(start: started, end: lastActive) : nil
    }
}
