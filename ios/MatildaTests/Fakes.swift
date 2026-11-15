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
