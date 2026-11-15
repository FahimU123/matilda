protocol CallChannel: AnyObject, Sendable {
    func events() -> AsyncStream<ServerEvent>
    func send(_ message: ClientMessage) async throws
}
