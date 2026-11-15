import Foundation
import SwiftData
import Testing
@testable import Matilda

struct LocalStoreTests {
    let store: LocalStore

    init() throws {
        store = try LocalStore(inMemory: true)
    }

    let profile = Profile(
        id: "ray",
        displayName: "Ray",
        pronoun: .he,
        condition: "Parkinson's",
        fields: [ProfileField(key: "dateOfBirth", label: "Date of birth", value: "March 4, 1952", sensitive: false)],
        places: [Place(id: "pharmacy", name: "Nest Street Pharmacy", kind: .pharmacy, phone: "", purpose: "Refill", fieldKeys: [])]
    )

    @Test func cachedProfileSurvivesWithoutTheServer() throws {
        try store.cache(profile)
        #expect(store.cachedProfile(id: "ray") == profile)
    }

    @Test func cachingTwiceKeepsOneCopy() throws {
        try store.cache(profile)
        var renamed = profile
        renamed.displayName = "Raymond"
        try store.cache(renamed)

        let copies = try store.container.mainContext.fetchCount(FetchDescriptor<CachedProfile>())
        #expect(copies == 1)
        #expect(store.cachedProfile(id: "ray")?.displayName == "Raymond")
    }

    @Test func recordingACallKeepsEveryAnswer() throws {
        try store.record(
            callID: "c1",
            placeName: "Nest Street Pharmacy",
            startedAt: .now,
            summary: "Refill ordered for delivery",
            answers: [ConsentEntry(question: "Date of birth?", answer: "March 4, 1952", method: .nod, at: 1_700_000_000_000)]
        )
        let logs = try store.container.mainContext.fetch(FetchDescriptor<CallLog>())
        let log = try #require(logs.first)
        #expect(log.answers.map(\.method) == [.nod])
    }

    @Test func deletingACallDeletesItsAnswers() throws {
        try store.record(
            callID: "c2",
            placeName: "Dr. Patel's office",
            startedAt: .now,
            summary: "Appointment confirmed",
            answers: [ConsentEntry(question: "Insurance ID?", answer: "MBR 7731 0094", method: .thumbs, at: 1_700_000_000_000)]
        )
        let context = store.container.mainContext
        for log in try context.fetch(FetchDescriptor<CallLog>()) { context.delete(log) }
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<AnsweredQuestion>()) == 0)
    }
}
