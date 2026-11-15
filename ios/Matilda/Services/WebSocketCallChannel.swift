import Foundation
import os

/// Keeps one socket open for the profile and fans incoming events out to every subscriber.
nonisolated final class WebSocketCallChannel: CallChannel {
    private let url: URL
    private let session: URLSession
    private let state = OSAllocatedUnfairLock(initialState: State())
    private let logger = Logger(subsystem: "app.matilda", category: "socket")

    private struct State {
        var task: URLSessionWebSocketTask?
        var subscribers: [UUID: AsyncStream<ServerEvent>.Continuation] = [:]
        var runner: Task<Void, Never>?
    }

    init(serverURL: URL, profileID: String, appKey: String, session: URLSession = .shared) {
        var components = URLComponents(url: serverURL.appending(path: "ws/app/\(profileID)"), resolvingAgainstBaseURL: false)
        components?.scheme = serverURL.scheme == "https" ? "wss" : "ws"
        components?.queryItems = [URLQueryItem(name: "key", value: appKey)]
        self.url = components?.url ?? serverURL
        self.session = session
    }

    func start() {
        state.withLock { state in
            guard state.runner == nil else { return }
            state.runner = Task { [weak self] in await self?.run() }
        }
    }

    func events() -> AsyncStream<ServerEvent> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: ServerEvent.self, bufferingPolicy: .bufferingNewest(64))
        state.withLock { $0.subscribers[id] = continuation }
        continuation.onTermination = { [weak self] _ in
            self?.state.withLock { _ = $0.subscribers.removeValue(forKey: id) }
        }
        return stream
    }

    func send(_ message: ClientMessage) async throws {
        let data = try JSONEncoder().encode(message)
        guard let task = state.withLock({ $0.task }) else { throw URLError(.notConnectedToInternet) }
        try await task.send(.string(String(decoding: data, as: UTF8.self)))
    }

    private func run() async {
        var delay = Duration.milliseconds(500)
        while !Task.isCancelled {
            let task = session.webSocketTask(with: url)
            state.withLock { $0.task = task }
            task.resume()
            do {
                while true {
                    let message = try await task.receive()
                    delay = .milliseconds(500)
                    publish(message)
                }
            } catch {
                logger.info("Socket closed: \(error.localizedDescription)")
            }
            state.withLock { $0.task = nil }
            try? await Task.sleep(for: delay)
            delay = min(delay * 2, .seconds(8))
        }
    }

    private func publish(_ message: URLSessionWebSocketTask.Message) {
        let data: Data? = switch message {
        case .string(let text): Data(text.utf8)
        case .data(let data): data
        @unknown default: nil
        }
        guard let data, let event = try? JSONDecoder().decode(ServerEvent.self, from: data) else { return }
        let subscribers = state.withLock { Array($0.subscribers.values) }
        for subscriber in subscribers { subscriber.yield(event) }
    }
}
