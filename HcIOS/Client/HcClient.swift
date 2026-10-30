import Foundation

protocol HcClient {
    func list() async throws -> [TerminalInfo]
    func read(_ id: String) async throws -> String
    func send(_ id: String, text: String) async throws
    func keys(_ id: String, _ keys: [String]) async throws
    func test() async throws -> String
}

struct HcError: LocalizedError {
    let kind: String
    let message: String
    var errorDescription: String? { message }
}
