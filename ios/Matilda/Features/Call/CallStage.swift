nonisolated enum CallStage: Equatable, Sendable {
    case ringing
    case live
    case ended(summary: String?)
    case failed(String)
}
