protocol SecureVault: Sendable {
    func store(_ value: String, for key: String) throws
    func hasValue(for key: String) -> Bool
    func reveal(_ key: String, reason: String) async throws -> String
    func remove(_ key: String) throws
}
