import SwiftUI

struct SetupView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            Section {
                ForEach(model.profile?.sensitiveFields ?? []) { field in
                    PrivateNumberRow(field: field)
                }
            } header: {
                Text(Copy.privateNumbers)
            } footer: {
                Text("Saved only on this iPhone. \(Copy.assistantName) asks for Face ID before saying one.")
            }

            Section {
                NavigationLink("Practice answering", value: Route.practice)
            } header: {
                Text("Practice")
            } footer: {
                Text("Mouth yes, no, or a number to answer. While a question is on screen, a short clip of your mouth goes to the \(Copy.assistantName) server to be read.")
            }

            Section {
                LabeledContent("AirPods", value: model.gestures.airPodsConnected ? "Connected" : "Put them in to answer with a nod")
                LabeledContent("Camera", value: model.gestures.cameraSupported ? "Ready" : "Needs an iPhone with Face ID")
            } header: {
                Text("Ways to say it")
            } footer: {
                Text("\(Copy.places) and \(Copy.details.lowercased()) are set up by family on the \(Copy.assistantName) website.")
            }
        }
        .navigationTitle("Setup")
        .font(.title3)
    }
}
