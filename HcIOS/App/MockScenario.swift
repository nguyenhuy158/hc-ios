import Foundation

enum MockScenario: String, CaseIterable {
    case list, many, loading, empty, disconnected
    case detail, detailWorking, detailLong
    case settings, settingsFailed, firstLaunch
    case hostKey, hostKeyChanged
    case lock

    static var current: MockScenario? {
        UserDefaults.standard.string(forKey: "mock").flatMap(MockScenario.init(rawValue:))
    }

    func makeModel() -> AppModel {
        let model = AppModel()
        model.terminals = MockData.terminals
        model.connection = .connected
        switch self {
        case .list, .settings:
            break
        case .many:
            model.terminals = MockData.manyTerminals
        case .loading:
            model.terminals = []
            model.connection = .connecting
        case .empty:
            model.terminals = []
        case .disconnected:
            model.connection = .disconnected("Can't reach mac-mini.tail1234.ts.net:22 — timed out after 10 s")
        case .detail:
            model.path = [MockData.terminals[0]]
        case .detailWorking:
            model.path = [MockData.terminals[2]]
        case .detailLong:
            model.path = [MockData.terminals[3]]
        case .settingsFailed:
            model.client = MockHcClient(testError: HcError(kind: "auth", message: "Permission denied (publickey). Add the key below to ~/.ssh/authorized_keys on the Mac."))
        case .firstLaunch:
            model.terminals = []
            model.host = ""
            model.user = ""
        case .hostKey:
            model.hostKeyPrompt = HostKeyPrompt(host: model.host, fingerprint: "SHA256:q3Vx8kTn0e7LmB2pR9sYwZc4HfJ1aUo6dGi5NvK2tXE", previous: nil)
        case .hostKeyChanged:
            model.hostKeyPrompt = HostKeyPrompt(host: model.host, fingerprint: "SHA256:Z9pLm2Qw7rT4vB8nX1cK6yH3sD0fJ5gA2eU7iO4kR1M", previous: "SHA256:q3Vx8kTn0e7LmB2pR9sYwZc4HfJ1aUo6dGi5NvK2tXE")
        case .lock:
            model.locked = true
        }
        model.showSettings = [.settings, .settingsFailed, .firstLaunch].contains(self)
        return model
    }
}
