import SwiftUI

struct CallControls: View {
    let call: CallViewModel
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var endSize = 80.0

    var body: some View {
        let compact = typeSize.isAccessibilitySize
        let layout = compact ? AnyLayout(HStackLayout(spacing: 16)) : AnyLayout(VStackLayout(spacing: 16))
        layout {
            SensorStrip(compact: compact)
            Button(action: hangUp) {
                VStack(spacing: 8) {
                    Image(systemName: "phone.down.fill")
                        .font(compact ? .title : .largeTitle)
                        .foregroundStyle(.white)
                        .frame(width: compact ? 72 : endSize, height: compact ? 72 : endSize)
                        .background(Theme.hangUp, in: .circle)
                    if !compact {
                        Text(Copy.endCall)
                            .font(.body.bold())
                            .foregroundStyle(Theme.ink)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Copy.endCall)
        }
        .padding(.horizontal, compact ? 24 : 0)
        .padding(.top, compact ? 12 : 16)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(Theme.paper)
    }

    private func hangUp() {
        Task { await call.hangUp() }
    }
}
