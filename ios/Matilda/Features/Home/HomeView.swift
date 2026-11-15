import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("hasPracticed") private var hasPracticed = false
    @State private var showsPractice = false

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Group {
                switch model.load {
                case .loading:
                    ProgressView("Getting your calls ready")
                        .font(.title3)
                case .failed(let message):
                    ContentUnavailableView {
                        Label("Can't reach Matilda", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Try again", action: retry)
                            .buttonStyle(.borderedProminent)
                    }
                case .ready(let profile):
                    PlaceList(profile: profile)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.mist)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .setup: SetupView()
                case .practice: PracticeView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("Setup", value: Route.setup)
                }
            }
        }
        .task {
            showsPractice = !hasPracticed
            await model.refresh()
        }
        .fullScreenCover(item: $model.activeCall) { call in
            CallView(call: call, onClose: model.closeCall)
        }
        .onChange(of: model.practiceRequests) {
            showsPractice = true
        }
        .fullScreenCover(isPresented: $showsPractice) {
            PracticeView(onFinish: finishPractice)
        }
        .alert("Call didn't start", isPresented: $model.showsStartError, presenting: model.startError) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    private func finishPractice() {
        hasPracticed = true
        showsPractice = false
    }

    private func retry() {
        Task { await model.refresh() }
    }
}

#Preview {
    HomeView()
        .environment(AppModel(configuration: .init(serverURL: URL(string: "http://localhost:8787")!, profileID: "ray", appKey: "")))
}
