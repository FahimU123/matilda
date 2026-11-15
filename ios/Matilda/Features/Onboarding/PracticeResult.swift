import SwiftUI

struct PracticeResult: View {
    let title: String
    let detail: String
    let onAgain: () -> Void
    let onFinish: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                MatildaMarkBadge(size: 28)
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(Theme.ink)
            }
            Text(detail)
                .font(.title3)
                .foregroundStyle(Theme.inkSoft)
            HStack(spacing: 12) {
                Button("Try again", action: onAgain)
                    .buttonStyle(.bordered)
                if let onFinish {
                    Button("Start using Matilda", action: onFinish)
                        .buttonStyle(.borderedProminent)
                }
            }
            .font(.title3.bold())
            .controlSize(.large)
        }
        .padding(20)
        .background(Theme.paper, in: .rect(cornerRadius: Theme.corner))
    }
}
