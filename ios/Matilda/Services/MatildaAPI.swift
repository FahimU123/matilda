protocol MatildaAPI: Sendable {
    func profile(id: String) async throws -> Profile
    func startCall(profileID: String, placeID: String) async throws -> String
}
