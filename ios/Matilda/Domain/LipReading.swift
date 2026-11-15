/// `heard` is the raw lip reading; `sentence` is the cleaned-up version Matilda would say.
nonisolated struct LipReading: Decodable, Equatable, Sendable {
    var heard: String
    var sentence: String
}
