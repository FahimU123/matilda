import SwiftUI

/// Shows Ray, at a glance, that the camera can see him and is following his lips.
struct LipWatchIndicator: View {
    let status: RecordingStatus?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var size = 88.0

    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(faceVisible ? Theme.confirmSoft : Theme.mist)
                Circle()
                    .strokeBorder(faceVisible ? Theme.confirm : Theme.wait, lineWidth: 3)
                    .scaleEffect(moving && !reduceMotion ? 1.12 : 1)
                    .opacity(moving ? 1 : 0.6)
                Image(systemName: faceVisible ? "mouth.fill" : "face.dashed")
                    .font(.largeTitle)
                    .foregroundStyle(faceVisible ? Theme.confirm : Theme.wait)
            }
            .frame(width: size, height: size)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: moving)

            Text(message)
                .font(.title3.bold())
                .foregroundStyle(faceVisible ? Theme.ink : Theme.wait)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var faceVisible: Bool { status?.faceVisible ?? true }
    private var moving: Bool { status?.lipsMoving ?? false }

    private var message: String {
        if !faceVisible { return "Can't see your face. Hold the phone in front of you" }
        return moving ? "Watching your lips" : "Ready when you are"
    }
}
