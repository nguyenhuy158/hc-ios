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

extension Date {
    func elapsedShort(now: Date = .now) -> String {
        let f = DateComponentsFormatter()
        f.unitsStyle = .abbreviated
        f.maximumUnitCount = 1
        f.allowedUnits = [.day, .hour, .minute, .second]
        return f.string(from: max(0, now.timeIntervalSince(self))) ?? ""
    }
}
