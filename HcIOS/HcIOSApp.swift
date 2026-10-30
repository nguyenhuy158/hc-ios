import SwiftUI

@main
struct HcIOSApp: App {
    @State private var model = MockScenario.current.makeModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        if model.locked {
            LockView()
        } else {
            NavigationStack(path: $model.path) {
                TerminalListView()
                    .navigationDestination(for: TerminalInfo.self) { TerminalDetailView(terminal: $0) }
            }
            .sheet(isPresented: $model.showSettings) { SettingsView() }
            .sheet(item: $model.hostKeyPrompt) { HostKeyView(prompt: $0) }
        }
    }
}
