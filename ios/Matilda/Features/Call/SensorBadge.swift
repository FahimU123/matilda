import SwiftUI

struct SensorBadge: View {
    let title: String
    let systemImage: String
    let isOn: Bool
    let isFiring: Bool
    let pulse: Int
    var compact = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lit = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .frame(width: 52, height: 44)
                    .foregroundStyle(lit ? .white : (isOn ? Theme.confirm : Theme.inkSoft.opacity(0.5)))
                    .background(lit ? Theme.confirm : (isOn ? Theme.confirmSoft : .clear), in: .rect(cornerRadius: 12))
                StatusDot(isOn: isOn)
                    .offset(x: 2, y: -2)
            }
            if !compact {
                Text(title)
                    .font(.footnote.bold())
                    .lineLimit(1)
                    .foregroundStyle(isOn ? Theme.ink : Theme.inkSoft)
            }
        }
        .frame(minWidth: 64)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(isOn ? "ready" : "not available")")
        .onChange(of: pulse) {
            guard isFiring else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { lit = true } completion: {
                withAnimation(.easeOut(duration: 0.6)) { lit = false }
            }
        }
    }
}
