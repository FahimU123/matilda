import SwiftUI

struct CallSummaryView: View {
    let placeName: String
    let purpose: String
    let summary: String?
    let duration: Duration?
    let consents: [ConsentEntry]
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        MatildaMarkBadge(size: 40)
                        Text("Call ended")
                            .font(.largeTitle.bold())
                            .foregroundStyle(Theme.ink)
                        if let duration {
                            Text("\(placeName), \(duration, format: .units(allowed: [.minutes, .seconds], width: .wide))")
                                .font(.title3)
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }

                    SummaryCard(title: "What happened", text: outcome)

                    if !consents.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("What \(Copy.assistantName) said for you")
                                .font(.title3.bold())
                                .foregroundStyle(Theme.ink)
                            ForEach(consents) { entry in
                                ConsentRow(entry: entry)
                            }
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: onDone) {
                Text("Done")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, minHeight: 64)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.confirm)
            .padding(24)
        }
    }

    private var outcome: String {
        if let summary, !summary.isEmpty { return summary }
        return "\(Copy.assistantName) called \(placeName) to \(purpose.prefix(1).lowercased() + purpose.dropFirst())."
    }
}
