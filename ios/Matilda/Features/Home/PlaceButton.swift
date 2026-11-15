import SwiftUI

struct PlaceButton: View {
    @Environment(AppModel.self) private var model
    let place: Place
    @ScaledMetric(relativeTo: .title) private var iconWidth = 44.0

    var body: some View {
        Button(action: call) {
            HStack(spacing: 18) {
                Image(systemName: symbol)
                    .font(.title)
                    .frame(width: iconWidth)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.title2.bold())
                    Text(place.purpose)
                        .font(.body)
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                if model.startingPlaceID == place.id {
                    ProgressView()
                } else {
                    Image(systemName: "phone.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.confirm)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(Theme.ink)
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: Theme.largeTarget)
            .background(Theme.paper, in: .rect(cornerRadius: Theme.corner))
        }
        .buttonStyle(.plain)
        .disabled(model.startingPlaceID != nil)
        .accessibilityLabel("Call \(place.name)")
        .accessibilityHint(place.purpose)
    }

    private var symbol: String {
        switch place.kind {
        case .pharmacy: "pills"
        case .doctor: "stethoscope"
        case .insurance: "doc.text"
        case .caseManager: "person.2"
        case .bank: "building.columns"
        case .utility: "bolt"
        case .other: "phone"
        }
    }

    private func call() {
        Task { await model.call(place) }
    }
}
