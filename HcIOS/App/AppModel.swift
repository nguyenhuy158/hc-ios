import SwiftUI

enum ConnectionState: Equatable {
    case connecting
    case connected
    case disconnected(String)
}

struct HostKeyPrompt: Identifiable {
    let id = UUID()
    let host: String
    let fingerprint: String
    let previous: String?
}

@Observable
final class AppModel {
    var client: HcClient
    var connection: ConnectionState = .connecting
    var terminals: [TerminalInfo] = []
    var locked = false
    var showSettings = false
    var hostKeyPrompt: HostKeyPrompt?
    var path: [TerminalInfo] = []

    var host = "mac-mini.tail1234.ts.net"
    var port = "22"
    var user = "huyntq"
    var hcPath = "~/.local/bin/herdr-core"
    let publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK7v1mQx3pWJ0yq9rT2nZ5fH8cLdE4sGbV6uY1oN3aRk hc-ios@iphone"

    init(client: HcClient = MockHcClient()) {
        self.client = client
    }

    var blockedCount: Int { terminals.filter { $0.status == .blocked }.count }

    func refresh() async {
        connection = .connecting
        do {
            terminals = try await client.list()
            connection = .connected
        } catch {
            connection = .disconnected(error.localizedDescription)
        }
    }
}
