import Foundation
import Observation

@Observable
final class CallViewModel: Identifiable {
    let callID: String
    let placeName: String
    let purpose: String

    private(set) var stage: CallStage = .ringing
    private(set) var captions: [TranscriptLine] = []
    private(set) var card: AnswerCard?
    private(set) var highlighted = 0
    private(set) var pending: PendingAnswer?
    private(set) var consents: [ConsentEntry] = []
    private(set) var notice: String?
    private(set) var confirmations = 0
    private(set) var rejections = 0
    private(set) var liveSince: Date?

    @ObservationIgnored private let channel: any CallChannel
    @ObservationIgnored private let events: AsyncStream<ServerEvent>
    @ObservationIgnored private let gestures: AsyncStream<GestureEvent>
    @ObservationIgnored private let vault: any SecureVault
    @ObservationIgnored private let commitDelay: Duration
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []
    @ObservationIgnored private(set) var commitTask: Task<Void, Never>?

    init(
        callID: String,
        placeName: String,
        purpose: String,
        channel: any CallChannel,
        events: AsyncStream<ServerEvent>,
        gestures: AsyncStream<GestureEvent>,
        vault: any SecureVault,
        commitDelay: Duration = .milliseconds(1200)
    ) {
        self.callID = callID
        self.placeName = placeName
        self.purpose = purpose
        self.channel = channel
        self.events = events
        self.gestures = gestures
        self.vault = vault
        self.commitDelay = commitDelay
    }

    var id: String { callID }

    var isWaitingOnUser: Bool { card != nil }

    var isFinished: Bool { stage.isFinished }

    private(set) var endedAt: Date?

    var duration: Duration? {
        guard let liveSince else { return nil }
        return .seconds((endedAt ?? .now).timeIntervalSince(liveSince).rounded())
    }

    func start() {
        guard tasks.isEmpty else { return }
        tasks.append(Task { [weak self, events] in
            for await event in events {
                self?.handle(event)
            }
        })
        tasks.append(Task { [weak self, gestures] in
            for await gesture in gestures {
                self?.handle(gesture)
            }
        })
    }

    func stop() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        commitTask?.cancel()
    }

    func handle(_ event: ServerEvent) {
        guard event.callID == callID else { return }
        switch event {
        case .phase(_, let phase, _):
            switch phase {
            case .ringing: break
            case .live, .waitingForUser:
                if case .ringing = stage {
                    stage = .live
                    liveSince = .now
                }
            case .ended:
                if !stage.isFinished { finish(summary: nil) }
            }
        case .transcript(_, let line):
            captions.append(line)
        case .cardOpened(_, let opened):
            card = opened
            highlighted = 0
            pending = nil
            notice = nil
        case .cardClosed(_, let cardID, _):
            guard card?.id == cardID else { return }
            card = nil
            pending = nil
            commitTask?.cancel()
        case .summary(_, let summary, let entries):
            consents = entries
            finish(summary: summary.isEmpty ? nil : summary)
        }
    }

    func handle(_ gesture: GestureEvent) {
        switch gesture {
        case .confirm(let method):
            approve(index: highlighted, method: method)
        case .decline(let method):
            reject(method: method)
        case .choose(let index, let method):
            approve(index: index, method: method)
        }
    }

    func tapSuggestion(at index: Int) {
        approve(index: index, method: .tap)
    }

    func tapNotRight() {
        reject(method: .tap)
    }

    func stopPending() {
        commitTask?.cancel()
        pending = nil
        notice = "Stopped. Nothing was said."
    }

    func hangUp() async {
        commitTask?.cancel()
        do {
            try await channel.send(.hangUp(callID: callID))
        } catch {
            notice = "Could not reach \(Copy.assistantName) to end the call. Tap End call again."
            return
        }
        if !stage.isFinished { finish(summary: nil) }
    }

    private func finish(summary: String?) {
        endedAt = endedAt ?? .now
        card = nil
        pending = nil
        commitTask?.cancel()
        stage = .ended(summary: summary)
    }

    private func approve(index: Int, method: ConfirmMethod) {
        guard let card, card.suggestions.indices.contains(index), pending == nil else { return }
        highlighted = index
        pending = PendingAnswer(cardID: card.id, index: index, method: method)
        confirmations += 1
        commitTask?.cancel()
        commitTask = Task { [weak self, commitDelay] in
            try? await Task.sleep(for: commitDelay)
            guard !Task.isCancelled else { return }
            await self?.commit()
        }
    }

    private func reject(method: ConfirmMethod) {
        guard let card else { return }
        if pending != nil {
            stopPending()
            return
        }
        rejections += 1
        notice = "\(Copy.assistantName) is telling them that's not right."
        Task { [weak self, channel] in
            do {
                try await channel.send(.decline(cardID: card.id, method: method))
            } catch {
                self?.notice = "Could not reach \(Copy.assistantName). Tap Not right again."
            }
        }
    }

    private func commit() async {
        guard let pending, let card, card.id == pending.cardID else { return }
        let suggestion = card.suggestions[pending.index]
        var value: String?

        if let key = card.sensitiveFieldKey {
            do {
                value = try await vault.reveal(key, reason: "Say your \(suggestion.label) to \(placeName)")
            } catch {
                self.pending = nil
                notice = error.localizedDescription
                return
            }
        }

        // Face ID can take seconds. If Ray stopped, the question closed or the call ended meanwhile, say nothing.
        guard !Task.isCancelled, self.pending == pending, self.card?.id == card.id else { return }

        do {
            try await channel.send(.answer(cardID: card.id, suggestionID: suggestion.id, method: pending.method, value: value))
        } catch {
            self.pending = nil
            notice = "Could not reach \(Copy.assistantName). Check the connection and try again."
        }
    }
}

private extension CallStage {
    var isFinished: Bool {
        switch self {
        case .ended, .failed: true
        case .ringing, .live: false
        }
    }
}
