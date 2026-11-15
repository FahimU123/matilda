nonisolated enum ClientMessage: Encodable, Equatable, Sendable {
    case answer(cardID: String, suggestionID: String, method: ConfirmMethod, value: String?)
    case decline(cardID: String, method: ConfirmMethod)
    case hangUp(callID: String)

    private enum CodingKeys: String, CodingKey {
        case type, cardId, suggestionId, method, value, callId
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .answer(let cardID, let suggestionID, let method, let value):
            try container.encode("answer", forKey: .type)
            try container.encode(cardID, forKey: .cardId)
            try container.encode(suggestionID, forKey: .suggestionId)
            try container.encode(method, forKey: .method)
            try container.encodeIfPresent(value, forKey: .value)
        case .decline(let cardID, let method):
            try container.encode("decline", forKey: .type)
            try container.encode(cardID, forKey: .cardId)
            try container.encode(method, forKey: .method)
        case .hangUp(let callID):
            try container.encode("hangup", forKey: .type)
            try container.encode(callID, forKey: .callId)
        }
    }
}
