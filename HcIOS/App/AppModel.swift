import LocalAuthentication
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
    var keyLine: String = ""
}

@Observable
final class AppModel {
    var client: HcClient
    var connection: ConnectionState = .connecting
    var terminals: [TerminalInfo] = []
    var locked = false
    var showSettings = false
    var hostKeyPrompt: HostKeyPrompt?
    var pairPrompt: PairRequest?
    var path: [TerminalInfo] = []
    let isMock: Bool

    var host: String { didSet { save() } }
    var port: String { didSet { save() } }
    var user: String { didSet { save() } }
    var hcPath: String { didSet { save() } }
    private(set) var requireFaceID: Bool

    @ObservationIgnored var makeClient: (ConnectionConfig) -> HcClient = { SSHHcClient(config: $0) }
    @ObservationIgnored private var attempt = 0
    @ObservationIgnored private var pendingOpen: String?
    @ObservationIgnored private var eventsTask: Task<Void, Never>?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?

    init(client: HcClient = MockHcClient(), isMock: Bool = true) {
        let d = UserDefaults.standard
        self.client = client
        self.isMock = isMock
        host = isMock ? "mac-mini.tail1234.ts.net" : d.string(forKey: "host") ?? ""
        port = isMock ? "22" : d.string(forKey: "port") ?? "22"
        user = isMock ? "huyntq" : d.string(forKey: "user") ?? ""
        hcPath = isMock ? "~/.local/bin/herdr-core" : d.string(forKey: "hcPath") ?? "~/.local/bin/herdr-core"
        requireFaceID = isMock ? true : d.object(forKey: "requireFaceID") as? Bool ?? true
    }

    static func live() -> AppModel {
        let model = AppModel(client: MockHcClient(terminals: []), isMock: false)
        model.locked = model.shouldLock
        model.showSettings = model.host.isEmpty || model.user.isEmpty
        return model
    }

    var config: ConnectionConfig {
        ConnectionConfig(host: host.trimmingCharacters(in: .whitespaces), port: Int(port) ?? 22,
                         user: user.trimmingCharacters(in: .whitespaces), hcPath: hcPath)
    }

    var publicKey: String { isMock ? "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK7v1mQx3pWJ0yq9rT2nZ5fH8cLdE4sGbV6uY1oN3aRk hc-ios@iphone" : KeyStore.publicKeyLine() }

    var trustedFingerprint: String? { HostKeyTrust.trusted(config.hostKeyID).map(HostKeyTrust.fingerprint) }

    var blockedCount: Int { terminals.filter { $0.status == .blocked }.count }

    private static var skipLock: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-uiTestingNoLock")
        #else
        false
        #endif
    }

    private var shouldLock: Bool { !isMock && !Self.skipLock && requireFaceID }

    func lock() {
        guard shouldLock else { return }
        locked = true
    }

    func unlock() async {
        if isMock {
            locked = false
            return
        }
        if await Self.authenticate("Unlock hc to see your terminals.") { locked = false }
    }

    func setRequireFaceID(_ on: Bool, authenticate: (() async -> Bool)? = nil) async {
        guard on != requireFaceID else { return }
        if !on {
            let ok: Bool
            if let authenticate {
                ok = await authenticate()
            } else {
                ok = await Self.authenticate("Turn off Face ID for hc.")
            }
            guard ok else { return }
        }
        requireFaceID = on
        if !isMock { UserDefaults.standard.set(on, forKey: "requireFaceID") }
    }

    private static func authenticate(_ reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return true }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }

    func start() async {
        guard !isMock else { return }
        _ = KeyStore.publicKeyLine()
        guard !host.isEmpty, !user.isEmpty else { return }
        await connect()
    }

    func connect() async {
        attempt += 1
        let current = attempt
        eventsTask?.cancel()
        await client.disconnect()
        let live = makeClient(config)
        client = live
        connection = .connecting
        do {
            try await live.connect()
            guard current == attempt else {
                await live.disconnect()
                return
            }
            connection = .connected
            await refresh()
            listenForEvents()
        } catch let error as HostKeyError {
            guard current == attempt else { return }
            hostKeyPrompt = HostKeyPrompt(host: error.host, fingerprint: error.fingerprint,
                                          previous: error.previousFingerprint, keyLine: error.keyLine)
            connection = .disconnected("Confirm the Mac's host key to connect.")
        } catch {
            guard current == attempt else { return }
            connection = .disconnected(error.localizedDescription)
        }
    }

    func trustHostKey(_ prompt: HostKeyPrompt) {
        HostKeyTrust.trust(prompt.host, keyLine: prompt.keyLine)
        hostKeyPrompt = nil
        Task { await connect() }
    }

    func forgetHostKey() {
        HostKeyTrust.forget(config.hostKeyID)
    }

    func pair(_ request: PairRequest, send: ((PairRequest) async throws -> Void)? = nil) async {
        pairPrompt = nil
        connection = .connecting
        do {
            if let send {
                try await send(request)
            } else {
                try await request.send(publicKey: KeyStore.publicKeyLine())
            }
        } catch {
            connection = .disconnected(error.localizedDescription)
            return
        }
        host = request.host
        port = request.port
        user = request.user
        hcPath = request.hcPath
        HostKeyTrust.trust(config.hostKeyID, keyLine: request.hostKey)
        showSettings = false
        hostKeyPrompt = nil
        if !isMock { await connect() } else { connection = .connected }
    }

    func open(_ url: URL) {
        if let request = PairRequest(url: url) {
            showSettings = false
            hostKeyPrompt = nil
            pairPrompt = request
            return
        }
        guard url.scheme == "hcios", url.host == "terminal" else { return }
        let id = String(url.path.dropFirst())
        guard !id.isEmpty else { return }
        pendingOpen = id
        openPending()
    }

    private func openPending() {
        guard let id = pendingOpen, let terminal = terminals.first(where: { $0.id == id }) else { return }
        pendingOpen = nil
        path = [terminal]
    }

    func refresh() async {
        if !isMock, connection != .connected {
            await connect()
            return
        }
        do {
            terminals = try await client.list()
            connection = .connected
            openPending()
        } catch {
            connection = .disconnected(error.localizedDescription)
        }
    }

    func reconnectIfNeeded() async {
        guard !isMock else { return }
        if connection == .connected, let fresh = try? await client.list() {
            terminals = fresh
            return
        }
        await connect()
    }

    func test() async throws -> String {
        if isMock { return try await client.test() }
        return try await SSHHcClient(config: config).test()
    }

    private func listenForEvents() {
        let stream = client.events()
        eventsTask = Task { [weak self] in
            for await _ in stream {
                self?.scheduleRefresh()
            }
        }
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }

    private func save() {
        guard !isMock else { return }
        let d = UserDefaults.standard
        d.set(host, forKey: "host")
        d.set(port, forKey: "port")
        d.set(user, forKey: "user")
        d.set(hcPath, forKey: "hcPath")
    }
}
