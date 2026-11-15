protocol LipReadingService: Sendable {
    func read(_ clip: LipClip) async throws -> LipCommand?
}
