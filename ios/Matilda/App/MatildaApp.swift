import SwiftData
import SwiftUI

@main
struct MatildaApp: App {
    @State private var model = AppModel(configuration: .fromBundle())

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(model)
                .modelContainer(container)
                .tint(Theme.confirm)
        }

        AssistiveAccess {
            HomeView()
                .environment(model)
                .modelContainer(container)
                .tint(Theme.confirm)
        }
    }

    private var container: ModelContainer {
        guard let container = model.store?.container else {
            fatalError("Matilda could not open its on-device store.")
        }
        return container
    }
}
