import SwiftUI

struct AnswerHint: View {
    let choices: Int
    let onNotRight: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(choices > 1 ? Copy.howToChoose : Copy.howToSayIt)
                .font(.title3.bold())
                .foregroundStyle(Theme.ink)
            Text(Copy.howToReject)
                .font(.title3)
                .foregroundStyle(Theme.inkSoft)
            Button(Copy.notRight, systemImage: "hand.thumbsdown", action: onNotRight)
                .font(.title3.bold())
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
    }
}
