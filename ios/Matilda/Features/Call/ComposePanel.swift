import SwiftUI

/// Saying an answer of his own: mouth it, check what Matilda read, then say it.
struct ComposePanel: View {
    @Bindable var call: CallViewModel
    let card: AnswerCard
    @Environment(AppModel.self) private var model
    @FocusState private var editing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.answerGap) {
            switch call.compose {
            case .idle:
                EmptyView()
            case .recording:
                recording
            case .reading:
                reading
            case .ready(let heard):
                ready(heard: heard)
            case .failed(let message):
                failed(message)
            }
        }
    }

    private var recording: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Mouth your answer")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.ink)
            LipWatchIndicator(status: model.gestures.recording)
            primaryButton("Done", systemImage: "checkmark") {
                Task { await call.finishComposing() }
            }
            Text("\(Copy.assistantName) asked them to hold. When your lips rest, she reads what you said.")
                .font(.title3)
                .foregroundStyle(Theme.inkSoft)
            secondaryActions(retry: false, typing: true)
        }
    }

    private var reading: some View {
        HStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)
            VStack(alignment: .leading, spacing: 4) {
                Text("Reading your lips")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.ink)
                Text("This takes a few seconds")
                    .font(.title3)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: .rect(cornerRadius: Theme.corner))
        .accessibilityElement(children: .combine)
    }

    private func ready(heard: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.answerGap) {
            Text("\(Copy.assistantName) will say")
                .font(.title3)
                .foregroundStyle(Theme.inkSoft)
            TextField("What should \(Copy.assistantName) say?", text: $call.draft, axis: .vertical)
                .font(.title.bold())
                .foregroundStyle(Theme.ink)
                .lineLimit(2...6)
                .focused($editing)
                .submitLabel(.done)
                .disabled(call.pending != nil)
                .padding(22)
                .background(Theme.confirmSoft, in: .rect(cornerRadius: Theme.corner))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.corner)
                        .strokeBorder(Theme.confirm, lineWidth: 3)
                }
            if !heard.isEmpty {
                Text("Read from your lips: \"\(heard)\". Tap the words to fix them.")
                    .font(.body)
                    .foregroundStyle(Theme.inkSoft)
            }

            if let pending = call.pending {
                SendingBanner(method: pending.method, sensitive: false, onStop: call.stopPending)
            } else {
                primaryButton("Say it", systemImage: "speaker.wave.2.fill") {
                    editing = false
                    call.sayDraft(method: .tap)
                }
                .disabled(call.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text("Or give a thumbs up or nod")
                    .font(.title3)
                    .foregroundStyle(Theme.inkSoft)
                secondaryActions(retry: !heard.isEmpty, typing: false)
            }
        }
        .onAppear { if heard.isEmpty { editing = true } }
    }

    private func failed(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Label {
                Text(message)
                    .font(.title3.bold())
                    .foregroundStyle(Theme.ink)
            } icon: {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(Theme.wait)
            }
            primaryButton(Copy.tryAgain, systemImage: "mouth") { call.retryComposing() }
            secondaryActions(retry: false, typing: true)
        }
    }

    private func primaryButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.title2.bold())
                .frame(maxWidth: .infinity, minHeight: 64)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.confirm)
    }

    private func secondaryActions(retry: Bool, typing: Bool) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { secondaryButtons(retry: retry, typing: typing) }
            VStack(alignment: .leading, spacing: 12) { secondaryButtons(retry: retry, typing: typing) }
        }
        .font(.title3.bold())
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    @ViewBuilder
    private func secondaryButtons(retry: Bool, typing: Bool) -> some View {
        if retry {
            Button(Copy.tryAgain, systemImage: "mouth", action: call.retryComposing)
        }
        if typing {
            Button(Copy.typeInstead, systemImage: "keyboard", action: call.typeInstead)
        }
        Button(Copy.backToAnswers, systemImage: "arrow.uturn.backward", action: call.cancelComposing)
    }
}
