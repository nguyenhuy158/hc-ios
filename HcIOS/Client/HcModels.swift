import Foundation

struct HcTerminal: Decodable {
    struct Status: Decodable {
        let state: String
        let app: String?
        let msg: String?
    }

    struct Foreground: Decodable {
        let name: String?
        let cwd: String?
    }

    let address: String
    let name: String?
    let title: String?
    let cwd: String
    let argv: [String]
    let state: String
    let created_ms: UInt64
    let status: Status?
    let status_ms: UInt64?
    let foreground: Foreground?
    let labels: [String: String]?

    var info: TerminalInfo {
        let program = status?.app ?? foreground?.name ?? argv.first.map { ($0 as NSString).lastPathComponent } ?? "?"
        let path = (foreground?.cwd ?? cwd).replacingOccurrences(of: NSHomeDirectory(), with: "~")
        let machine = address.split(separator: "/").dropLast().last.map(String.init)
        let folder = machine.map { "\($0):\(path)" } ?? path
        let shown = [name, title, labels?["where"]].compactMap { $0 }.first { !$0.isEmpty } ?? address
        return TerminalInfo(
            id: address,
            name: shown,
            program: program,
            folder: folder,
            status: TerminalStatus(hcState: status?.state),
            since: Date(timeIntervalSince1970: Double(status_ms ?? created_ms) / 1000),
            screen: ""
        )
    }
}

struct HcListResult: Decodable {
    let terminals: [HcTerminal]
}

struct HcReadResult: Decodable {
    let text: String
}

struct HcHelloResult: Decodable {
    let version: String
}

extension TerminalStatus {
    init(hcState: String?) {
        switch hcState {
        case "blocked", "error": self = .blocked
        case "working": self = .working
        case "done": self = .done
        default: self = .idle
        }
    }
}

enum HcJSON {
    static func decode<T: Decodable>(_ type: T.Type, from object: Any) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: object)
        return try JSONDecoder().decode(type, from: data)
    }
}
