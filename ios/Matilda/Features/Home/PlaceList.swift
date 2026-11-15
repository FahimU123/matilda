import SwiftUI

struct PlaceList: View {
    let profile: Profile
    #if DEBUG
    @AppStorage("hasPracticed") private var hasPracticed = false
    @Environment(AppModel.self) private var model
    @State private var confirmingReset = false
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Who should \(Copy.assistantName) call, \(profile.displayName)?")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.ink)
                    #if DEBUG
                    .onLongPressGesture(minimumDuration: 3) { confirmingReset = true }
                    .confirmationDialog("Reset the demo?", isPresented: $confirmingReset) {
                        Button("Reset demo", role: .destructive, action: resetDemo)
                    } message: {
                        Text("Clears recent calls and shows the practice screen again.")
                    }
                    #endif
                Text("You stay on the line. \(Copy.assistantName) speaks, you nod.")
                    .font(.title3)
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.bottom, 8)

                ForEach(profile.places) { place in
                    PlaceButton(place: place)
                }

                RecentCalls()
                    .padding(.top, 16)
            }
            .padding(24)
        }
    }

    #if DEBUG
    private func resetDemo() {
        try? model.store?.clearHistory()
        hasPracticed = false
        model.requestPractice()
    }
    #endif
}
