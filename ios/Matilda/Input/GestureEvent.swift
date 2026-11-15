nonisolated enum GestureEvent: Equatable, Sendable {
    case confirm(ConfirmMethod)
    case decline(ConfirmMethod)
    case choose(index: Int, method: ConfirmMethod)
}
