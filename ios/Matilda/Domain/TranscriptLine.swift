import Foundation

nonisolated struct TranscriptLine: Codable, Hashable, Identifiable, Sendable {
    var speaker: Speaker
    var text: String
    var at: Double

    var id: Double { at }
}
