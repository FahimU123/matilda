import SwiftUI

struct CaptionRow: View {
    let line: TranscriptLine
    let isCurrent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(line.speaker == .agent ? Copy.assistantName : "Them")
                .font(.body.bold())
                .foregroundStyle(line.speaker == .agent ? Theme.confirm : Theme.inkSoft)
            Text(line.text)
                .font(isCurrent ? .title.weight(.semibold) : .title3)
                .foregroundStyle(isCurrent ? Theme.ink : Theme.inkSoft)
        }
        .animation(.easeOut(duration: 0.2), value: isCurrent)
        .accessibilityElement(children: .combine)
    }
}
