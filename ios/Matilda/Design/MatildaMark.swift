import SwiftUI

/// The signature mark: a head dipping down and coming back up. Shown only where the person approved an answer.
nonisolated struct MatildaMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.25))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.25),
            control: CGPoint(x: rect.midX, y: rect.maxY * 1.35)
        )
        return path
    }
}

struct MatildaMarkBadge: View {
    var size: Double = 22

    var body: some View {
        MatildaMark()
            .stroke(Theme.confirm, style: StrokeStyle(lineWidth: size / 7, lineCap: .round))
            .frame(width: size, height: size * 0.6)
            .accessibilityHidden(true)
    }
}
