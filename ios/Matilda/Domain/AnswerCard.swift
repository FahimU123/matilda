nonisolated struct AnswerCard: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var question: String
    var suggestions: [Suggestion]
    var sensitiveFieldKey: String?

    var isSensitive: Bool { sensitiveFieldKey != nil }
}
