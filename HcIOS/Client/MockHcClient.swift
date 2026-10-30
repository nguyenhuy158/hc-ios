import Foundation

struct MockHcClient: HcClient {
    var terminals: [TerminalInfo] = MockData.terminals
    var testError: HcError?

    func list() async throws -> [TerminalInfo] { terminals }

    func read(_ id: String) async throws -> String {
        terminals.first { $0.id == id }?.screen ?? ""
    }

    func send(_ id: String, text: String) async throws {}

    func keys(_ id: String, _ keys: [String]) async throws {}

    func test() async throws -> String {
        if let testError { throw testError }
        return "hc 0.1.14"
    }
}

enum MockData {
    static func ago(_ seconds: TimeInterval) -> Date { .now.addingTimeInterval(-seconds) }

    static let claudePrompt = """
    ⏺ I'll add the retry wrapper around the SSH channel.

    ⏺ Update(HcIOS/Client/SSHChannel.swift)
      ⎿  Updated HcIOS/Client/SSHChannel.swift with 14 additions
          41 +    func reconnect() async throws {
          42 +        try await Task.sleep(for: .seconds(backoff))
          43 +        try await open()
          44 +    }

    ╭───────────────────────────────────────────────╮
    │ Bash command                                  │
    │                                               │
    │   xcodebuild -scheme HcIOS -destination       │
    │   'platform=iOS Simulator,name=iPhone 15'     │
    │   build                                       │
    │                                               │
    │ Do you want to proceed?                       │
    │ ❯ 1. Yes                                      │
    │   2. Yes, and don't ask again for xcodebuild  │
    │   3. No, and tell Claude what to do (esc)     │
    ╰───────────────────────────────────────────────╯
    """

    static let codexWorking = """
    • Reading services/farmnet/addons/farm_sale/models/sale_order.py
    • Running make test MODULE=farm_sale
      ├ 118 passed
      └ 2 failed: test_debt_limit_blocks_confirm, test_appendix_total

    • Explaining the debt limit failure…
    """

    static let longOutput = (1...80).map { "[\(String(format: "%02d", $0 % 60))s] step \($0): compiling target \($0 % 7 == 0 ? "NIOSSH" : "Citadel")" }
        .joined(separator: "\n")

    static let terminals: [TerminalInfo] = [
        .init(id: "t3", name: "hc-ios", program: "claude", folder: "~/Documents/personal-projects/hc-ios",
              status: .blocked, since: ago(4 * 60 + 12), screen: claudePrompt),
        .init(id: "t9", name: "farmnet-debt-limit-confirmation-for-appendix-orders", program: "codex",
              folder: "~/Documents/techcoop/tc-api/services/farmnet/.worktrees/debt-limit-confirmation-for-appendix-orders",
              status: .blocked, since: ago(41 * 60), screen: claudePrompt),
        .init(id: "t7", name: "farmnet", program: "codex", folder: "~/Documents/techcoop/tc-api",
              status: .working, since: ago(95), screen: codexWorking),
        .init(id: "t1b", name: "build", program: "make", folder: "~/Documents/personal-projects/hc-ios",
              status: .working, since: ago(20), screen: longOutput),
        .init(id: "t4", name: "homelab", program: "claude", folder: "~/Documents/personal-projects/homelab",
              status: .done, since: ago(3 * 3600), screen: "⏺ Bumped homelab and pushed 4ab0ec9.\n\n> "),
        .init(id: "t2", name: "zsh", program: "zsh", folder: "~",
              status: .idle, since: ago(2 * 86400), screen: "huyntq@mac ~ % "),
    ]

    static let manyTerminals: [TerminalInfo] = (1...24).map { i in
        let status = TerminalStatus.allCases[i % 4]
        return .init(id: "t\(i)", name: "agent-\(i)", program: i % 2 == 0 ? "claude" : "codex",
                     folder: "~/work/repo-\(i)", status: status, since: ago(Double(i * 137)), screen: codexWorking)
    }
}
