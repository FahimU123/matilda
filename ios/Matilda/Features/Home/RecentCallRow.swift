import SwiftUI

struct RecentCallRow: View {
    let call: CallLog

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(call.placeName), \(call.startedAt, format: .relative(presentation: .named))")
                .font(.body)
                .foregroundStyle(Theme.inkSoft)
            Text(call.summary)
                .font(.title3.bold())
                .foregroundStyle(Theme.ink)
            if !call.answers.isEmpty {
                HStack(spacing: 8) {
                    MatildaMarkBadge(size: 18)
                    Text("^[\(call.answers.count) answer](inflect: true) said for you")
                        .font(.body)
                        .foregroundStyle(Theme.confirm)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: .rect(cornerRadius: Theme.corner))
        .accessibilityElement(children: .combine)
    }
}
