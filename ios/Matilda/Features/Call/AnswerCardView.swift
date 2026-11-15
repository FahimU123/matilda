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
                        .font(call.compose == .idle ? .largeTitle.weight(.semibold) : .title2.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                }

                if call.compose == .idle {
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
                        if call.canCompose {
                            SayOwnAnswerButton(action: call.startComposing)
                        }
                        AnswerHint(choices: card.suggestions.count, onNotRight: call.tapNotRight)
                    }
                } else {
                    ComposePanel(call: call, card: card)
                }

                if let notice = call.notice {
                    Text(notice)
                        .font(.title3)
                        .foregroundStyle(Theme.wait)
                }
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        .animation(.snappy, value: call.pending)
        .animation(.snappy, value: call.compose)
    }
}
