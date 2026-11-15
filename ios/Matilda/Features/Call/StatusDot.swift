import SwiftUI

/// Filled when an input is ready, an empty ring when it is not, so the state never depends on color alone.
struct StatusDot: View {
    let isOn: Bool

    var body: some View {
        Circle()
            .fill(isOn ? Theme.confirm : Theme.paper)
            .strokeBorder(isOn ? Theme.paper : Theme.inkSoft.opacity(0.6), lineWidth: 2)
            .frame(width: 12, height: 12)
    }
}
