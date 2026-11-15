import SwiftUI

struct CallView: View {
    @Environment(AppModel.self) private var model
    let call: CallViewModel
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            CallHeader(call: call)
            Group {
                switch call.stage {
                case .ended(let summary):
                    CallSummaryView(
                        placeName: call.placeName,
                        purpose: call.purpose,
                        summary: summary,
                        duration: call.duration,
                        consents: call.consents,
                        onDone: onClose
                    )
                case .failed(let message):
                    ContentUnavailableView("Call failed", systemImage: "phone.down", description: Text(message))
                case .ringing, .live:
                    if let card = call.card {
                        AnswerCardView(call: call, card: card)
                    } else {
                        CaptionsView(lines: call.captions)
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            if !call.isFinished {
                CallControls(call: call)
            }
        }
        .background(Theme.mist)
        .sensoryFeedback(.impact(weight: .heavy), trigger: call.card?.id)
        .sensoryFeedback(.success, trigger: call.confirmations)
        .sensoryFeedback(.warning, trigger: call.rejections)
        .sensoryFeedback(.stop, trigger: call.isFinished)
        .onChange(of: call.card?.id, initial: true) { _, cardID in
            if let cardID { model.gestures.beginAnswering(cardID) } else { model.gestures.endAnswering() }
        }
        .onDisappear(perform: call.stop)
        #if DEBUG
        .task(id: call.card?.id) {
            guard call.card != nil else { return }
            switch UserDefaults.standard.string(forKey: "autoCompose") {
            case "record": call.startComposing()
            case "type": call.typeInstead()
            case "fail":
                call.startComposing()
                await call.finishComposing()
            default: break
            }
        }
        #endif
    }
}
