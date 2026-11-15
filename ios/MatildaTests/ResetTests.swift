import Foundation
import SwiftData
import Testing
@testable import Matilda

struct ResetTests {
    @Test func clearingHistoryRemovesCallsAndAnswers() throws {
        let store = try LocalStore(inMemory: true)
        try store.record(
            callID: "c1",
            placeName: "Nest Street Pharmacy",
            startedAt: .now,
            summary: "Refill ordered",
            answers: [ConsentEntry(question: "DOB?", answer: "March 4, 1952", method: .nod, at: 0)]
        )
        try store.clearHistory()

        let context = store.container.mainContext
        #expect(try context.fetchCount(FetchDescriptor<CallLog>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<AnsweredQuestion>()) == 0)
    }
}
