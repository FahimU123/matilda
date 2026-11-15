nonisolated struct Place: Codable, Hashable, Identifiable, Sendable {
    enum Kind: String, Codable, Sendable {
        case pharmacy, doctor, insurance, caseManager, bank, utility, other
    }

    var id: String
    var name: String
    var kind: Kind
    var phone: String
    var purpose: String
    var fieldKeys: [String]
}
