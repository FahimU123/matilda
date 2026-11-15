import SwiftData

enum MatildaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [MatildaSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
