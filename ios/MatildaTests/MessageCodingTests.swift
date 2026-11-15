import Foundation
import Testing
@testable import Matilda

struct MessageCodingTests {
    @Test func decodesAnOpenedCard() throws {
        let json = """
        {"type":"card.open","callId":"c1","card":{"id":"k","question":"DOB?","suggestions":[{"id":"0","label":"March 4, 1952","say":"His date of birth is March 4, 1952."}]}}
        """
        let event = try JSONDecoder().decode(ServerEvent.self, from: Data(json.utf8))
        let card = try #require(event.openedCard)
        #expect(card.suggestions.first?.label == "March 4, 1952")
        #expect(card.isSensitive == false)
    }

    @Test func decodesACardClosedWithoutSpeech() throws {
        let json = #"{"type":"card.closed","callId":"c1","cardId":"k","said":null}"#
        let event = try JSONDecoder().decode(ServerEvent.self, from: Data(json.utf8))
        #expect(event == .cardClosed(callID: "c1", cardID: "k", said: nil))
    }

    @Test func rejectsUnknownEvents() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ServerEvent.self, from: Data(#"{"type":"mystery","callId":"c1"}"#.utf8))
        }
    }

    @Test func encodesAnAnswerTheServerUnderstands() throws {
        let data = try JSONEncoder().encode(ClientMessage.answer(cardID: "k", suggestionID: "0", method: .nod, value: nil))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(object == ["type": "answer", "cardId": "k", "suggestionId": "0", "method": "nod"])
    }
}

private extension ServerEvent {
    var openedCard: AnswerCard? {
        if case .cardOpened(_, let card) = self { card } else { nil }
    }
}
