import SwiftUI

struct CaptionsView: View {
    let lines: [TranscriptLine]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if lines.isEmpty {
                        Text("Captions appear here as soon as someone speaks")
                            .font(.title2)
                            .foregroundStyle(Theme.inkSoft)
                    }
                    ForEach(lines) { line in
                        CaptionRow(line: line, isCurrent: line.id == lines.last?.id)
                            .id(line.id)
                    }
                }
                .padding(24)
            }
            .onChange(of: lines.count) {
                if let last = lines.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }
    }
}
