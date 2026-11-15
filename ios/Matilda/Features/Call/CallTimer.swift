import SwiftUI

struct CallTimer: View {
    let since: Date

    var body: some View {
        TimelineView(.periodic(from: since, by: 1)) { context in
            Text(Duration.seconds(max(0, context.date.timeIntervalSince(since))), format: .time(pattern: .minuteSecond))
                .font(.title3.monospacedDigit())
                .foregroundStyle(Theme.inkSoft)
        }
        .accessibilityLabel("Call time")
    }
}
