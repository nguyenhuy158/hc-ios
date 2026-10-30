import Foundation

actor RPCLink {
    private var writer: (@Sendable (Data) async throws -> Void)?
    private var waiting: [CheckedContinuation<Void, Error>] = []
    private var pending: [Int: CheckedContinuation<Any, Error>] = [:]
    private var nextID = 1
    private var buffer = Data()
    private var closedError: Error?
    private let onNotification: @Sendable ([String: Any]) -> Void

    init(onNotification: @escaping @Sendable ([String: Any]) -> Void = { _ in }) {
        self.onNotification = onNotification
    }

    func attach(_ writer: @escaping @Sendable (Data) async throws -> Void) {
        self.writer = writer
        waiting.forEach { $0.resume() }
        waiting = []
    }

    func ready() async throws {
        if let closedError { throw closedError }
        if writer != nil { return }
        try await withCheckedThrowingContinuation { waiting.append($0) }
    }

    func call(_ method: String, _ params: [String: Any] = [:]) async throws -> Any {
        if let closedError { throw closedError }
        guard let writer else { throw HcError(kind: "closed", message: "Not connected to hc.") }
        let id = nextID
        nextID += 1
        let message: [String: Any] = ["jsonrpc": "2.0", "id": id, "method": method, "params": params]
        var line = try JSONSerialization.data(withJSONObject: message)
        line.append(0x0A)
        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            Task {
                do {
                    try await writer(line)
                } catch {
                    self.resolve(id, .failure(error))
                }
            }
        }
    }

    func feed(_ chunk: Data) {
        buffer.append(chunk)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            guard !line.isEmpty,
                  let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
            if let id = object["id"] as? Int {
                if let error = object["error"] as? [String: Any] {
                    let kind = (error["data"] as? [String: Any])?["kind"] as? String ?? "error"
                    resolve(id, .failure(HcError(kind: kind, message: error["message"] as? String ?? "hc error")))
                } else {
                    resolve(id, .success(object["result"] ?? NSNull()))
                }
            } else {
                onNotification(object)
            }
        }
    }

    func close(_ error: Error) {
        closedError = error
        waiting.forEach { $0.resume(throwing: error) }
        waiting = []
        pending.values.forEach { $0.resume(throwing: error) }
        pending = [:]
        writer = nil
    }

    private func resolve(_ id: Int, _ result: Result<Any, Error>) {
        guard let continuation = pending.removeValue(forKey: id) else { return }
        continuation.resume(with: result)
    }
}
