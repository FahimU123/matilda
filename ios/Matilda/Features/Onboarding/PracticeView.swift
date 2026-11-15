import SwiftUI

struct PracticeView: View {
    @Environment(AppModel.self) private var model
    @State private var practice: PracticeViewModel?
    var onFinish: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.answerGap) {
            if onFinish != nil {
                Text("\(Copy.assistantName) speaks for you on phone calls. When someone asks a question, your answer appears here and you say it without speaking.")
                    .font(.title3)
                    .foregroundStyle(Theme.ink)
                    .padding(.bottom, 8)
            }
            Text("Try it now")
                .font(.title3)
                .foregroundStyle(Theme.inkSoft)
            Text("Is your name \(model.profile?.displayName ?? "Ray")?")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(Theme.ink)

            if let practice {
                switch practice.result {
                case .waiting:
                    SuggestionButton(
                        suggestion: Suggestion(id: "0", label: "Yes, that's me", say: "Yes, that's me."),
                        number: 1,
                        isHighlighted: true,
                        isSending: false,
                        showsNumber: false,
                        action: practice.tap
                    )
                    Text(Copy.howToSayIt)
                        .font(.title3.bold())
                    Text(Copy.howToReject)
                        .font(.title3)
                        .foregroundStyle(Theme.inkSoft)
                case .said(let method):
                    PracticeResult(
                        title: "\(Copy.assistantName) would say: \"Yes, that's me.\"",
                        detail: "You answered with \(methodName(method)). That is all it takes on a real call.",
                        onAgain: practice.reset,
                        onFinish: onFinish
                    )
                case .stopped:
                    PracticeResult(
                        title: "Stopped. Nothing was said.",
                        detail: "A head shake or thumbs down always stops \(Copy.assistantName).",
                        onAgain: practice.reset,
                        onFinish: onFinish
                    )
                }
            }
            Spacer(minLength: 0)
            if let onFinish {
                Button("Skip for now", action: onFinish)
                    .font(.title3)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.mist)
        .sensoryFeedback(.success, trigger: practice?.result)
        .onAppear(perform: begin)
        .onDisappear(perform: end)
    }

    private func methodName(_ method: ConfirmMethod) -> String {
        switch method {
        case .thumbs: "a thumbs up"
        case .nod: "a nod"
        case .lips: "your lips"
        case .tap: "a tap"
        case .voice: "your voice"
        }
    }

    private func begin() {
        guard practice == nil else { return }
        model.gestures.start()
        model.gestures.beginAnswering("practice")
        let viewModel = PracticeViewModel(gestures: model.gestures.events())
        viewModel.start()
        practice = viewModel
    }

    private func end() {
        practice?.stop()
        practice = nil
        if model.activeCall == nil { model.gestures.stop() }
    }
}
