import SwiftUI

struct SendingBanner: View {
    let method: ConfirmMethod
    let sensitive: Bool
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sensitive ? "Checking it's you, then \(Copy.assistantName) says it" : "\(Copy.assistantName) is saying it")
                        .font(.title3.bold())
                    Text(Copy.shakeToStop)
                        .font(.body)
                        .foregroundStyle(Theme.inkSoft)
                }
            } icon: {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(Theme.confirm)
            }
            Spacer(minLength: 0)
            Button(Copy.stop, action: onStop)
                .font(.title3.bold())
                .buttonStyle(.borderedProminent)
                .tint(Theme.ink)
                .controlSize(.large)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: .rect(cornerRadius: Theme.corner))
    }

    private var icon: String {
        switch method {
        case .thumbs: "hand.thumbsup.fill"
        case .nod: "airpodspro"
        case .lips: "mouth"
        case .tap: "hand.tap"
        case .voice: "waveform"
        }
    }
}
