import SwiftUI

/// The way out when none of the suggestions fit.
struct SayOwnAnswerButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: "mouth")
                    .font(.title)
                    .foregroundStyle(Theme.confirm)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(Copy.sayOwnAnswer)
                        .font(.title2.bold())
                        .foregroundStyle(Theme.ink)
                    Text("Mouth it or type it")
                        .font(.body)
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: Theme.largeTarget, alignment: .leading)
            .overlay {
                RoundedRectangle(cornerRadius: Theme.corner)
                    .strokeBorder(Theme.inkSoft.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            }
            .contentShape(.rect(cornerRadius: Theme.corner))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Mouth or type an answer of your own")
    }
}
