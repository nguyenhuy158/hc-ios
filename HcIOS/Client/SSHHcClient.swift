import Citadel
import Foundation
import NIOCore

struct ConnectionConfig: Equatable {
    var host: String
    var port: Int
    var user: String
    var hcPath: String

    var hostKeyID: String { port == 22 ? host : "\(host):\(port)" }

    static func isSafeHcPath(_ path: String) -> Bool {
        !path.isEmpty && path.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "_./~-".contains($0)) }
    }
}

final class SSHHcClient: HcClient {
    let config: ConnectionConfig
    private var ssh: SSHClient?
    private var rpc = RPCLink()

    init(config: ConnectionConfig) {
        self.config = config
    }

    func connect() async throws {
        let key = try KeyStore.privateKey()
        let client: SSHClient
        do {
            client = try await SSHClient.connect(
                host: config.host,
                port: config.port,
                authenticationMethod: .ed25519(username: config.user, privateKey: key),
                hostKeyValidator: .custom(HostKeyTrust.Validator(host: config.hostKeyID)),
                reconnect: .never,
                connectTimeout: .seconds(10)
            )
        } catch let error as HostKeyError {
            throw error
        } catch {
            throw HcError(kind: "ssh", message: Self.describe(error, config: config))
        }
        ssh = client
        rpc = RPCLink()
        open(rpc, on: client)
        try await rpc.ready()
        _ = try await rpc.call("hello")
    }

    func disconnect() async {
        await rpc.close(HcError(kind: "closed", message: "Disconnected."))
        try? await ssh?.close()
        ssh = nil
    }

    func list() async throws -> [TerminalInfo] {
        let result = try await rpc.call("terminal.list")
        return try HcJSON.decode(HcListResult.self, from: result).terminals.map(\.info)
    }

    func read(_ id: String) async throws -> String {
        let result = try await rpc.call("terminal.read", ["terminal": id, "lines": 200])
        return try HcJSON.decode(HcReadResult.self, from: result).text
    }

    func send(_ id: String, text: String) async throws {
        _ = try await rpc.call("terminal.send", ["terminal": id, "text": text])
    }

    func keys(_ id: String, _ keys: [String]) async throws {
        _ = try await rpc.call("terminal.keys", ["terminal": id, "keys": keys])
    }

    func test() async throws -> String {
        let probe = SSHHcClient(config: config)
        try await probe.connect()
        let hello = try await probe.rpc.call("hello")
        await probe.disconnect()
        return "hc " + (try HcJSON.decode(HcHelloResult.self, from: hello).version)
    }

    func events() -> AsyncStream<Void> {
        AsyncStream { continuation in
            guard let ssh else {
                continuation.finish()
                return
            }
            let link = RPCLink { _ in continuation.yield() }
            open(link, on: ssh) {
                continuation.finish()
            }
            let task = Task {
                do {
                    try await link.ready()
                    _ = try await link.call("hello")
                    _ = try await link.call("events.subscribe")
                } catch {
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
                Task { await link.close(CancellationError()) }
            }
        }
    }

    private func open(_ link: RPCLink, on client: SSHClient, onClose: @escaping @Sendable () -> Void = {}) {
        guard ConnectionConfig.isSafeHcPath(config.hcPath) else {
            Task { await link.close(HcError(kind: "config", message: "The hc path may only contain letters, digits and _ . / ~ -")) }
            return
        }
        let command = "exec \(config.hcPath) connect"
        Task {
            do {
                try await client.withExec(command) { inbound, outbound in
                    await link.attach { data in try await outbound.write(ByteBuffer(bytes: Array(data))) }
                    for try await output in inbound {
                        if case .stdout(let buffer) = output {
                            await link.feed(Data(buffer.readableBytesView))
                        }
                    }
                }
                await link.close(HcError(kind: "closed", message: "hc connect ended."))
            } catch {
                await link.close(HcError(kind: "hc", message: "Could not run \(command): \(error.localizedDescription)"))
            }
            onClose()
        }
    }

    private static func describe(_ error: Error, config: ConnectionConfig) -> String {
        let text = String(describing: error)
        if text.localizedCaseInsensitiveContains("auth") {
            return "Permission denied for \(config.user). Add this iPhone's key to ~/.ssh/authorized_keys on the Mac."
        }
        if text.localizedCaseInsensitiveContains("timeout") || text.localizedCaseInsensitiveContains("connect") {
            return "Can't reach \(config.host):\(config.port). Check Tailscale and Remote Login."
        }
        return text
    }
}
