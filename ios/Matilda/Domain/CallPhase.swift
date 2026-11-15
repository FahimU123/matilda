nonisolated enum CallPhase: String, Codable, Sendable {
    case ringing, live, waitingForUser, ended
}
