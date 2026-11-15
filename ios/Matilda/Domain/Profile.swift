nonisolated struct Profile: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var displayName: String
    var pronoun: Pronoun
    var condition: String
    var fields: [ProfileField]
    var places: [Place]

    var sensitiveFields: [ProfileField] { fields.filter(\.sensitive) }
}
