import Foundation
@testable import Matilda

final class SpyChannel: CallChannel, @unchecked Sendable {
    private(set) var sent: [ClientMessage] = []

    func events() -> AsyncStream<ServerEvent> {
        AsyncStream { _ in }
    }

    func send(_ message: ClientMessage) async throws {
        sent.append(message)
    }
}

struct StubVault: SecureVault {
    var value: String?

    func store(_ value: String, for key: String) throws {}
    func hasValue(for key: String) -> Bool { value != nil }
    func reveal(_ key: String, reason: String) async throws -> String {
        guard let value else { throw VaultError.notAuthenticated }
        return value
    }
    func remove(_ key: String) throws {}
}

enum Sample {
    static let dobCard = AnswerCard(
        id: "card-1",
        question: "What's his date of birth?",
        suggestions: [Suggestion(id: "0", label: "March 4, 1952", say: "His date of birth is March 4, 1952.")],
        sensitiveFieldKey: nil
    )

    static let choiceCard = AnswerCard(
        id: "card-2",
        question: "Pickup or delivery?",
        suggestions: [
            Suggestion(id: "0", label: "Pickup", say: "Pickup, please."),
            Suggestion(id: "1", label: "Delivery", say: "Delivery, please."),
        ],
        sensitiveFieldKey: nil
    )

    static let ssnCard = AnswerCard(
        id: "card-3",
        question: "Last four of the social?",
        suggestions: [Suggestion(id: "0", label: "•••• 6789", say: "His social security number is {{value}}.")],
        sensitiveFieldKey: "ssn"
    )
}

/// Like Face ID, ignores task cancellation and answers after a moment.
struct SlowVault: SecureVault {
    var value = "6789"
    func store(_ value: String, for key: String) throws {}
    func hasValue(for key: String) -> Bool { true }
    func reveal(_ key: String, reason: String) async throws -> String {
        try? await Task.sleep(for: .milliseconds(100))
        return value
    }
    func remove(_ key: String) throws {}
}

final class FakeRecorder: LipRecorder {
    var clip: LipClip? = LipClip(frames: Array(repeating: Data([0xFF]), count: 10), fps: 25)
    private(set) var isRecording = false
    private var onFinished: (() -> Void)?

    func startRecording(onFinished: @escaping () -> Void) {
        isRecording = true
        self.onFinished = onFinished
    }

    func finishRecording() -> LipClip? {
        isRecording = false
        return clip
    }

    func cancelRecording() {
        isRecording = false
    }

    func lipsRested() {
        onFinished?()
    }
}

struct StubReader: AnswerReader {
    var reading = LipReading(heard: "i need my carbon dopa", sentence: "I need a refill of my carbidopa-levodopa.")
    func readAnswer(cardID: String, clip: LipClip) async throws -> LipReading { reading }
}
