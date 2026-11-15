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
    private(set) var compose: ComposeStage = .idle
    /// The sentence Ray will say. Filled in from his lips, and he can edit or type it.
    var draft = "" {
        didSet { if draft.count > Self.draftLimit { draft = String(draft.prefix(Self.draftLimit)) } }
    }
    /// The server refuses longer sentences.
    static let draftLimit = 300

    @ObservationIgnored private let channel: any CallChannel
    @ObservationIgnored private let events: AsyncStream<ServerEvent>
    @ObservationIgnored private let gestures: AsyncStream<GestureEvent>
    @ObservationIgnored private let vault: any SecureVault
    @ObservationIgnored private let recorder: any LipRecorder
    @ObservationIgnored private let reader: any AnswerReader
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
        recorder: any LipRecorder,
        reader: any AnswerReader,
        commitDelay: Duration = .milliseconds(1200)
    ) {
        self.callID = callID
        self.placeName = placeName
        self.purpose = purpose
        self.channel = channel
        self.events = events
        self.gestures = gestures
        self.vault = vault
        self.recorder = recorder
        self.reader = reader
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
        resetCompose()
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
            resetCompose()
        case .cardClosed(_, let cardID, _):
            guard card?.id == cardID else { return }
            card = nil
            pending = nil
            commitTask?.cancel()
            resetCompose()
        case .summary(_, let summary, let entries):
            consents = entries
            finish(summary: summary.isEmpty ? nil : summary)
        }
    }

    func handle(_ gesture: GestureEvent) {
        switch compose {
        case .idle: break
        case .recording, .reading: return
        case .ready:
            switch gesture {
            case .confirm(let method): sayDraft(method: method)
            case .decline: if pending != nil { stopPending() } else { resetCompose() }
            case .choose: break
            }
            return
        case .failed:
            if case .decline = gesture { resetCompose() }
            return
        }
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

    // MARK: Saying something else

    var canCompose: Bool {
        guard let card, !card.isSensitive, pending == nil else { return false }
        return compose == .idle
    }

    func startComposing() {
        guard canCompose, let card else { return }
        notice = nil
        draft = ""
        compose = .recording
        recorder.startRecording { [weak self] in
            Task { await self?.finishComposing() }
        }
        Task { [channel] in try? await channel.send(.composing(cardID: card.id)) }
    }

    func finishComposing() async {
        guard compose == .recording, let card else { return }
        compose = .reading
        guard let clip = recorder.finishRecording() else {
            compose = .failed("\(Copy.assistantName) couldn't see your lips move. Hold the phone in front of your face and try again.")
            return
        }
        do {
            let reading = try await reader.readAnswer(cardID: card.id, clip: clip)
            guard compose == .reading, self.card?.id == card.id else { return }
            draft = reading.sentence
            compose = .ready(heard: reading.heard)
        } catch {
            guard compose == .reading else { return }
            compose = .failed(error.localizedDescription)
        }
    }

    /// Skips lip reading for anyone who would rather type.
    func typeInstead() {
        guard card != nil, pending == nil else { return }
        if compose == .recording { recorder.cancelRecording() }
        if case .ready = compose { return }
        draft = ""
        compose = .ready(heard: "")
    }

    func cancelComposing() {
        resetCompose()
    }

    func retryComposing() {
        resetCompose()
        startComposing()
    }

    func sayDraft(method: ConfirmMethod) {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard case .ready = compose, let card, !text.isEmpty, pending == nil else { return }
        pending = PendingAnswer(cardID: card.id, index: -1, method: method, text: text)
        confirmations += 1
        commitTask?.cancel()
        commitTask = Task { [weak self, commitDelay] in
            try? await Task.sleep(for: commitDelay)
            guard !Task.isCancelled else { return }
            await self?.commit()
        }
    }

    private func resetCompose() {
        if compose == .recording { recorder.cancelRecording() }
        compose = .idle
        draft = ""
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
        resetCompose()
        stage = .ended(summary: summary)
    }

    private func approve(index: Int, method: ConfirmMethod) {
        guard compose == .idle, let card, card.suggestions.indices.contains(index), pending == nil else { return }
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
        if let text = pending.text {
            do {
                try await channel.send(.say(cardID: card.id, text: text, method: pending.method))
            } catch {
                self.pending = nil
                notice = "Could not reach \(Copy.assistantName). Check the connection and try again."
            }
            return
        }
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
