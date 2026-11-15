import SwiftUI

struct SuggestionButton: View {
    let suggestion: Suggestion
    let number: Int
    let isHighlighted: Bool
    let isSending: Bool
    let showsNumber: Bool
    let action: () -> Void
    @ScaledMetric(relativeTo: .title) private var numberSize = 44.0

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                if showsNumber {
                    Text(number, format: .number)
                        .font(.title.bold())
                        .frame(width: numberSize, height: numberSize)
                        .background(isHighlighted ? Theme.confirm : Theme.mist, in: .circle)
                        .foregroundStyle(isHighlighted ? .white : Theme.ink)
                        .accessibilityHidden(true)
                }
                Text(suggestion.label)
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if isSending {
                    ProgressView()
                        .controlSize(.large)
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, minHeight: Theme.largeTarget)
            .background(isHighlighted ? Theme.confirmSoft : Theme.paper, in: .rect(cornerRadius: Theme.corner))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.corner)
                    .strokeBorder(isHighlighted ? Theme.confirm : .clear, lineWidth: 3)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(suggestion.label)
        .accessibilityHint("Says: \(suggestion.say)")
        .accessibilityInputLabels(showsNumber ? [suggestion.label, "\(number)"] : [suggestion.label])
    }
}
