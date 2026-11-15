/// Where Ray is in saying an answer of his own, instead of picking a suggestion.
enum ComposeStage: Equatable {
    case idle
    case recording
    case reading
    case ready(heard: String)
    case failed(String)
}
