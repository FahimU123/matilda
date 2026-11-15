import SwiftData
import SwiftUI

struct RecentCalls: View {
    @Query private var calls: [CallLog]

    init() {
        var descriptor = FetchDescriptor<CallLog>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        descriptor.fetchLimit = 3
        _calls = Query(descriptor)
    }

    var body: some View {
        if !calls.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent calls")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.ink)
                ForEach(calls) { call in
                    RecentCallRow(call: call)
                }
            }
        }
    }
}
