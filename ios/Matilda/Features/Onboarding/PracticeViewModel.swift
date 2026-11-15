import Foundation
import Observation

/// A practice question that needs no server, so anyone can try answering with a gesture in seconds.
@Observable
final class PracticeViewModel {
    enum Result: Equatable {
        case waiting
        case said(ConfirmMethod)
        case stopped
    }

    private(set) var result: Result = .waiting
    @ObservationIgnored private let gestures: AsyncStream<GestureEvent>
    @ObservationIgnored private var task: Task<Void, Never>?

    init(gestures: AsyncStream<GestureEvent>) {
        self.gestures = gestures
    }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self, gestures] in
            for await gesture in gestures {
                self?.handle(gesture)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    func handle(_ gesture: GestureEvent) {
        switch gesture {
        case .confirm(let method), .choose(_, let method): result = .said(method)
        case .decline: result = .stopped
        }
    }

    func tap() {
        result = .said(.tap)
    }

    func reset() {
        result = .waiting
    }
}
