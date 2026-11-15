import Foundation
import SwiftData

/// On-device copy of the person's details and a history of their calls, so the app keeps working offline.
final class LocalStore {
    let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init(inMemory: Bool = false) throws {
        if !inMemory {
            try FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
        }
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        container = try ModelContainer(
            for: Schema(versionedSchema: MatildaSchemaV1.self),
            migrationPlan: MatildaMigrationPlan.self,
            configurations: configuration
        )
    }

    func cachedProfile(id: String) -> Profile? {
        var descriptor = FetchDescriptor<CachedProfile>(predicate: #Predicate { $0.profileID == id })
        descriptor.fetchLimit = 1
        guard let cached = try? context.fetch(descriptor).first else { return nil }
        return try? JSONDecoder().decode(Profile.self, from: cached.payload)
    }

    func cache(_ profile: Profile) throws {
        let payload = try JSONEncoder().encode(profile)
        let id = profile.id
        var descriptor = FetchDescriptor<CachedProfile>(predicate: #Predicate { $0.profileID == id })
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            existing.payload = payload
            existing.updatedAt = .now
        } else {
            context.insert(CachedProfile(profileID: id, payload: payload))
        }
        try context.save()
    }

    func clearHistory() throws {
        try context.delete(model: CallLog.self)
        try context.save()
    }

    func record(callID: String, placeName: String, startedAt: Date, summary: String, answers: [ConsentEntry]) throws {
        let log = CallLog(callID: callID, placeName: placeName, startedAt: startedAt, endedAt: .now, summary: summary)
        context.insert(log)
        for entry in answers {
            let answer = AnsweredQuestion(
                question: entry.question,
                answer: entry.answer,
                method: entry.method,
                askedAt: Date(timeIntervalSince1970: entry.at / 1000)
            )
            answer.call = log
            context.insert(answer)
        }
        try context.save()
    }
}
