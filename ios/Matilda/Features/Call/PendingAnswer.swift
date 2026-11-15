/// An answer Ray has approved that is about to be spoken. It can still be cancelled
/// with a shake or thumbs down for a moment, so a stray gesture never speaks for him.
nonisolated struct PendingAnswer: Equatable, Sendable {
    var cardID: String
    var index: Int
    var method: ConfirmMethod
    /// Set when Ray is saying a sentence of his own instead of one of the suggestions.
    var text: String? = nil
}
