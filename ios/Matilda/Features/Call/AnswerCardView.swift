import SwiftUI

struct AnswerCardView: View {
    let call: CallViewModel
    let card: AnswerCard

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.answerGap) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Copy.theyAsked)
                        .font(.title3)
                        .foregroundStyle(Theme.inkSoft)
                    Text(card.question)
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                }

                ForEach(card.suggestions.enumerated(), id: \.element.id) { index, suggestion in
                    SuggestionButton(
                        suggestion: suggestion,
                        number: index + 1,
                        isHighlighted: index == call.highlighted,
                        isSending: call.pending?.index == index,
                        showsNumber: card.suggestions.count > 1,
                        action: { call.tapSuggestion(at: index) }
                    )
                }

                if let pending = call.pending {
                    SendingBanner(method: pending.method, sensitive: card.isSensitive, onStop: call.stopPending)
                } else {
                    AnswerHint(choices: card.suggestions.count, onNotRight: call.tapNotRight)
                }

                if let notice = call.notice {
                    Text(notice)
                        .font(.title3)
                        .foregroundStyle(Theme.wait)
                }
            }
            .padding(24)
        }
        .animation(.snappy, value: call.pending)
    }
}
