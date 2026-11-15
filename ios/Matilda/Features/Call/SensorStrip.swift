import SwiftUI

struct SensorStrip: View {
    @Environment(AppModel.self) private var model
    var compact = false

    var body: some View {
        let hub = model.gestures
        VStack(spacing: 10) {
            HStack(spacing: compact ? 8 : 24) {
                SensorBadge(title: "Thumbs", systemImage: "hand.thumbsup", isOn: hub.cameraRunning, isFiring: hub.lastSource == .camera, pulse: hub.signals, compact: compact)
                SensorBadge(title: "Head nod", systemImage: "airpodspro", isOn: hub.airPodsConnected, isFiring: hub.lastSource == .airPods, pulse: hub.signals, compact: compact)
                SensorBadge(title: "Lips", systemImage: "mouth", isOn: hub.cameraRunning, isFiring: hub.lastSource == .lips, pulse: hub.signals, compact: compact)
            }
            if !compact {
                Text(hub.lastSignal.map { "Heard: \($0)" } ?? "Ways to answer")
                    .font(.callout)
                    .foregroundStyle(Theme.inkSoft)
                    .contentTransition(.opacity)
            }
        }
        .padding(.horizontal, compact ? 0 : 24)
    }
}
