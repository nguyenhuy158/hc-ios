import SwiftUI

enum TerminalStatus: String, CaseIterable, Codable {
    case blocked, working, done, idle

    var title: String {
        switch self {
        case .blocked: "Needs you"
        case .working: "Working"
        case .done: "Done"
        case .idle: "Idle"
        }
    }

    var symbol: String {
        switch self {
        case .blocked: "exclamationmark.bubble.fill"
        case .working: "circle.dotted.circle"
        case .done: "checkmark.circle.fill"
        case .idle: "moon.zzz"
        }
    }

    var tint: Color {
        switch self {
        case .blocked: .orange
        case .working: .blue
        case .done: .green
        case .idle: .secondary
        }
    }
}

struct TerminalInfo: Identifiable, Hashable {
    let id: String
    var name: String
    var program: String
    var folder: String
    var status: TerminalStatus
    var since: Date
    var screen: String
}

extension TerminalInfo {
    static func sections(_ terminals: [TerminalInfo]) -> [(status: TerminalStatus, items: [TerminalInfo])] {
        TerminalStatus.allCases.compactMap { status in
            let items = terminals.filter { $0.status == status }.sorted { $0.since < $1.since }
            return items.isEmpty ? nil : (status, items)
        }
    }

    var shortFolder: String {
        let pieces = folder.split(separator: ":", maxSplits: 1).map(String.init)
        let machine = pieces.count == 2 ? pieces[0] + " · " : ""
        let path = pieces.last ?? folder
        let parts = path.split(separator: "/")
        return machine + (parts.count > 2 ? parts.suffix(2).joined(separator: "/") : path)
    }
}

extension Date {
    func elapsedShort(now: Date = .now) -> String {
        let f = DateComponentsFormatter()
        f.unitsStyle = .abbreviated
        f.maximumUnitCount = 1
        f.allowedUnits = [.day, .hour, .minute, .second]
        return f.string(from: max(0, now.timeIntervalSince(self))) ?? ""
    }
}
