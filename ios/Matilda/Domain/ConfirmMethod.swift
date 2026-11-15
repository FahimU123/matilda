nonisolated enum ConfirmMethod: String, Codable, Sendable {
    case thumbs, nod, lips, tap, voice

    var pastTense: String {
        switch self {
        case .thumbs: "Thumbs"
        case .nod: "Nodded"
        case .lips: "Mouthed"
        case .tap: "Tapped"
        case .voice: "Said"
        }
    }
}
