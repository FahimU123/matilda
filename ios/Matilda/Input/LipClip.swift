import Foundation

nonisolated struct LipClip: Sendable {
    var frames: [Data]
    var fps: Double
}
