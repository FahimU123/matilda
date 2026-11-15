nonisolated struct ConsentEntry: Codable, Hashable, Identifiable, Sendable {
    var question: String
    var answer: String
    var method: ConfirmMethod
    var at: Double

    var id: Double { at }
}
