import SwiftUI

struct ConsentRow: View {
    let entry: ConsentEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            MatildaMarkBadge(size: 20)
                .padding(.top, 8)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.answer)
                    .font(.title3.bold())
                    .foregroundStyle(Theme.ink)
                Text(entry.question)
                    .font(.body)
                    .foregroundStyle(Theme.inkSoft)
                Text(entry.method.pastTense)
                    .font(.callout.bold())
                    .foregroundStyle(Theme.confirm)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Theme.paper, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}
