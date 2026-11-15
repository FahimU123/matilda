import Foundation
import SwiftData

enum MatildaSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [CachedProfile.self, CallLog.self, AnsweredQuestion.self] }

    @Model
    final class CachedProfile {
        #Unique<CachedProfile>([\.profileID])

        var profileID: String
        var payload: Data
        var updatedAt: Date

        init(profileID: String, payload: Data, updatedAt: Date = .now) {
            self.profileID = profileID
            self.payload = payload
            self.updatedAt = updatedAt
        }
    }

    @Model
    final class CallLog {
        #Unique<CallLog>([\.callID])
        #Index<CallLog>([\.startedAt])

        var callID: String
        var placeName: String
        var startedAt: Date
        var endedAt: Date
        var summary: String
        @Relationship(deleteRule: .cascade, inverse: \AnsweredQuestion.call) var answers: [AnsweredQuestion] = []

        init(callID: String, placeName: String, startedAt: Date, endedAt: Date, summary: String) {
            self.callID = callID
            self.placeName = placeName
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.summary = summary
        }
    }

    @Model
    final class AnsweredQuestion {
        var question: String
        var answer: String
        var method: ConfirmMethod
        var askedAt: Date
        var call: CallLog?

        init(question: String, answer: String, method: ConfirmMethod, askedAt: Date) {
            self.question = question
            self.answer = answer
            self.method = method
            self.askedAt = askedAt
        }
    }
}

typealias CachedProfile = MatildaSchemaV1.CachedProfile
typealias CallLog = MatildaSchemaV1.CallLog
typealias AnsweredQuestion = MatildaSchemaV1.AnsweredQuestion
