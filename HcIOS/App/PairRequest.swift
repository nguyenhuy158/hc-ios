import Foundation
import Network

struct PairRequest: Equatable, Identifiable {
    var id: String { token }
    let host: String
    let port: String
    let user: String
    let hcPath: String
    let hostKey: String
    let endpoint: URL
    let token: String

    init?(url: URL) {
        guard url.scheme == "hcios", url.host == "pair",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return nil }
        let q = Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a })
        guard let host = q["host"], !host.isEmpty, let user = q["user"], !user.isEmpty,
              let hostKey = q["hostkey"], hostKey.hasPrefix("ssh-ed25519 "),
              let endpoint = q["url"].flatMap(URL.init(string:)), endpoint.scheme == "tcp", endpoint.host != nil, endpoint.port != nil,
              let token = q["token"], !token.isEmpty else { return nil }
        self.host = host
        self.port = q["port"].flatMap { $0.isEmpty ? nil : $0 } ?? "22"
        self.user = user
        self.hcPath = q["hc"].flatMap { $0.isEmpty ? nil : $0 } ?? "~/.local/bin/herdr-core"
        guard ConnectionConfig.isSafeHcPath(hcPath), Int(port) != nil else { return nil }
        self.hostKey = hostKey
        self.endpoint = endpoint
        self.token = token
    }

    var hostKeyID: String { port == "22" ? host : "\(host):\(port)" }

    var fingerprint: String { HostKeyTrust.fingerprint(hostKey) }

    var previousFingerprint: String? {
        HostKeyTrust.trusted(hostKeyID).flatMap { $0 == hostKey ? nil : HostKeyTrust.fingerprint($0) }
    }

    func send(publicKey: String) async throws {
        let payload = try JSONSerialization.data(withJSONObject: ["token": token, "key": publicKey]) + Data("\n".utf8)
        let reply = try await Self.exchange(host: endpoint.host ?? "", port: UInt16(endpoint.port ?? 0), payload: payload)
        let object = (try? JSONSerialization.jsonObject(with: reply)) as? [String: Any]
        guard object?["ok"] as? Bool == true else {
            let message = object?["message"] as? String ?? "unknown error"
            throw HcError(kind: "pair", message: "The Mac refused pairing: \(message). Run hc-pair again.")
        }
    }

    private static func exchange(host: String, port: UInt16, payload: Data) async throws -> Data {
        guard let port = NWEndpoint.Port(rawValue: port) else { throw HcError(kind: "pair", message: "Bad pairing address.") }
        let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .tcp)
        defer { connection.cancel() }
        let queue = DispatchQueue(label: "hc.pair")
        return try await withCheckedThrowingContinuation { continuation in
            var finished = false
            func finish(_ result: Result<Data, Error>) {
                guard !finished else { return }
                finished = true
                continuation.resume(with: result)
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: payload, completion: .contentProcessed { error in
                        if let error { finish(.failure(error)) }
                    })
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, error in
                        if let data, !data.isEmpty {
                            finish(.success(data))
                        } else {
                            finish(.failure(error ?? HcError(kind: "pair", message: "The Mac closed the pairing connection.")))
                        }
                    }
                case .failed(let error), .waiting(let error):
                    finish(.failure(error))
                default:
                    break
                }
            }
            queue.asyncAfter(deadline: .now() + 10) {
                finish(.failure(HcError(kind: "pair", message: "Could not reach the Mac at \(host). Is Tailscale on?")))
            }
            connection.start(queue: queue)
        }
    }
}
