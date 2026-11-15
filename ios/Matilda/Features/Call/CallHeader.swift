import SwiftUI

struct CallHeader: View {
    let call: CallViewModel
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(call.placeName)
                .font(.title.bold())
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(spacing: 12))
            layout {
                Label(status.text, systemImage: status.symbol)
                    .font(.title3)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(status.color)
                if !typeSize.isAccessibilitySize { Spacer() }
                if let since = call.liveSince, !call.isFinished {
                    CallTimer(since: since)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var status: (text: String, symbol: String, color: Color) {
        switch call.stage {
        case .ringing: ("Calling", "phone.arrow.up.right", Theme.inkSoft)
        case .live where call.isWaitingOnUser: ("Your answer is ready", "hand.raised", Theme.wait)
        case .live: ("\(Copy.assistantName) is on the call", "waveform", Theme.confirm)
        case .ended: ("Call ended", "phone.down", Theme.inkSoft)
        case .failed: ("Call failed", "exclamationmark.triangle", Theme.hangUp)
        }
    }
}
