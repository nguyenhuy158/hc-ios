import Foundation

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
              let endpoint = q["url"].flatMap(URL.init(string:)), ["http", "https"].contains(endpoint.scheme),
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
        var request = URLRequest(url: endpoint.appending(path: "pair"), timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["token": token, "key": publicKey])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let code = (response as? HTTPURLResponse)?.statusCode, code == 200 else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
            throw HcError(kind: "pair", message: "The Mac refused pairing: \(message ?? "unknown error"). Run hc-pair again.")
        }
    }
}
