nonisolated enum ServerEvent: Decodable, Equatable, Sendable {
    case phase(callID: String, phase: CallPhase, placeName: String)
    case transcript(callID: String, line: TranscriptLine)
    case cardOpened(callID: String, card: AnswerCard)
    case cardClosed(callID: String, cardID: String, said: String?)
    case summary(callID: String, summary: String, consents: [ConsentEntry])

    var callID: String {
        switch self {
        case .phase(let id, _, _), .transcript(let id, _), .cardOpened(let id, _),
             .cardClosed(let id, _, _), .summary(let id, _, _):
            id
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, callId, phase, placeName, line, card, cardId, said, summary, consents
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let callID = try container.decode(String.self, forKey: .callId)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "call.state":
            self = .phase(
                callID: callID,
                phase: try container.decode(CallPhase.self, forKey: .phase),
                placeName: try container.decode(String.self, forKey: .placeName)
            )
        case "transcript":
            self = .transcript(callID: callID, line: try container.decode(TranscriptLine.self, forKey: .line))
        case "card.open":
            self = .cardOpened(callID: callID, card: try container.decode(AnswerCard.self, forKey: .card))
        case "card.closed":
            self = .cardClosed(
                callID: callID,
                cardID: try container.decode(String.self, forKey: .cardId),
                said: try container.decodeIfPresent(String.self, forKey: .said)
            )
        case "call.summary":
            self = .summary(
                callID: callID,
                summary: try container.decode(String.self, forKey: .summary),
                consents: try container.decode([ConsentEntry].self, forKey: .consents)
            )
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown event \(type)")
        }
    }
}
