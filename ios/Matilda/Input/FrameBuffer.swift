import CoreImage
import Foundation

/// Keeps the last few seconds of small upright JPEG frames so a mouthed word can be sent as a clip.
nonisolated struct FrameBuffer {
    private var frames: [(time: TimeInterval, jpeg: Data)] = []
    private let span: TimeInterval = 4

    mutating func append(_ jpeg: Data, at time: TimeInterval) {
        frames.append((time, jpeg))
        frames.removeAll { time - $0.time > span }
    }

    func clip(for word: MouthedWord, padding: TimeInterval = 0.2) -> LipClip? {
        let selected = frames.filter { $0.time >= word.start - padding && $0.time <= word.end + padding }
        guard selected.count >= 4, let first = selected.first, let last = selected.last, last.time > first.time else {
            return nil
        }
        let fps = Double(selected.count - 1) / (last.time - first.time)
        return LipClip(frames: selected.map(\.jpeg), fps: fps)
    }
}
