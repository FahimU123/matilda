/// Turns a clip of Ray mouthing a sentence into what Matilda should say.
protocol AnswerReader: Sendable {
    func readAnswer(cardID: String, clip: LipClip) async throws -> LipReading
}
