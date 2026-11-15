nonisolated struct ProfileField: Codable, Hashable, Identifiable, Sendable {
    var key: String
    var label: String
    var value: String
    var sensitive: Bool

    var id: String { key }
}
