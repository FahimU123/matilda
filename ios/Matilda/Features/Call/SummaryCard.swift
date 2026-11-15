import SwiftUI

struct SummaryCard: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.body.bold())
                .foregroundStyle(Theme.inkSoft)
            Text(text)
                .font(.title2)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: .rect(cornerRadius: Theme.corner))
        .accessibilityElement(children: .combine)
    }
}
