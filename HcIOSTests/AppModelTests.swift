import XCTest
@testable import HcIOS

final class AppModelTests: XCTestCase {
    func testOpenURLSelectsTerminal() {
        let model = AppModel()
        model.terminals = MockData.terminals
        model.open(URL(string: "hcios://terminal/t7")!)
        XCTAssertEqual(model.path.map(\.id), ["t7"])
    }

    func testOpenURLWithMachineAddress() {
        let model = AppModel()
        var remote = MockData.terminals[0]
        remote = TerminalInfo(id: "pipi/t1", name: "root / 1", program: "bash", folder: "pipi:/root",
                              status: .idle, since: remote.since, screen: "")
        model.terminals = [remote]
        model.open(URL(string: "hcios://terminal/pipi%2Ft1")!)
        XCTAssertEqual(model.path.map(\.id), ["pipi/t1"])
    }

    func testOpenURLWaitsForListThenIgnoresOtherSchemes() async {
        let model = AppModel(client: MockHcClient(terminals: MockData.terminals))
        model.open(URL(string: "hcios://terminal/t4")!)
        XCTAssertTrue(model.path.isEmpty)
        await model.refresh()
        XCTAssertEqual(model.path.map(\.id), ["t4"])

        model.path = []
        model.open(URL(string: "https://terminal/t4")!)
        XCTAssertTrue(model.path.isEmpty)
    }

    private let pairURL = URL(string: "hcios://pair?host=mac.ts.net&port=22&user=huy&hc=~/.local/bin/herdr-core&hostkey=ssh-ed25519%20AAAA%2B%2F&url=tcp://100.1.2.3:5000&token=tok")!

    func testPairRequestParsesQRLink() {
        let request = PairRequest(url: pairURL)
        XCTAssertEqual(request?.host, "mac.ts.net")
        XCTAssertEqual(request?.user, "huy")
        XCTAssertEqual(request?.hostKey, "ssh-ed25519 AAAA+/")
        XCTAssertEqual(request?.endpoint.absoluteString, "tcp://100.1.2.3:5000")
        XCTAssertEqual(request?.token, "tok")
        XCTAssertNil(PairRequest(url: URL(string: "hcios://pair?host=mac&user=huy&hostkey=ssh-rsa%20AAAA&url=http://x&token=t")!))
        XCTAssertNil(PairRequest(url: URL(string: "hcios://terminal/t1")!))
        XCTAssertNil(PairRequest(url: URL(string: pairURL.absoluteString.replacingOccurrences(of: "tcp://", with: "http://"))!))
    }

    func testPairLinkOnlyAsksForConfirmation() {
        let model = AppModel()
        let before = model.host
        model.showSettings = true
        model.open(pairURL)
        XCTAssertEqual(model.pairPrompt?.token, "tok")
        XCTAssertFalse(model.showSettings)
        XCTAssertEqual(model.host, before)
        XCTAssertNil(HostKeyTrust.trusted("mac.ts.net"))
    }

    func testPairLinkRejectsUnsafeHcPath() {
        for hc in ["rm%20-rf%20~", "x;id", "$(id)", "a%60b%60", "a|b", ""] {
            let url = URL(string: pairURL.absoluteString.replacingOccurrences(of: "hc=~/.local/bin/herdr-core", with: "hc=\(hc)"))!
            if hc.isEmpty {
                XCTAssertEqual(PairRequest(url: url)?.hcPath, "~/.local/bin/herdr-core")
            } else {
                XCTAssertNil(PairRequest(url: url), hc)
            }
        }
        XCTAssertTrue(ConnectionConfig.isSafeHcPath("~/.local/bin/herdr-core"))
        XCTAssertFalse(ConnectionConfig.isSafeHcPath("hc connect; id"))
    }

    func testPairShowsChangedHostKey() {
        HostKeyTrust.trust("mac.ts.net", keyLine: "ssh-ed25519 AAAAOTHER")
        defer { HostKeyTrust.forget("mac.ts.net") }
        XCTAssertNotNil(PairRequest(url: pairURL)?.previousFingerprint)
        HostKeyTrust.trust("mac.ts.net", keyLine: "ssh-ed25519 AAAA+/")
        XCTAssertNil(PairRequest(url: pairURL)?.previousFingerprint)
    }

    func testPairFillsSettingsAndTrustsHostKey() async {
        let model = AppModel()
        model.showSettings = true
        var sent: PairRequest?
        await model.pair(PairRequest(url: pairURL)!) { sent = $0 }
        defer { HostKeyTrust.forget("mac.ts.net") }
        XCTAssertEqual(sent?.token, "tok")
        XCTAssertEqual([model.host, model.port, model.user], ["mac.ts.net", "22", "huy"])
        XCTAssertEqual(HostKeyTrust.trusted("mac.ts.net"), "ssh-ed25519 AAAA+/")
        XCTAssertFalse(model.showSettings)
        XCTAssertEqual(model.connection, .connected)
    }

    func testPairFailureKeepsSettings() async {
        let model = AppModel()
        let before = model.host
        await model.pair(PairRequest(url: pairURL)!) { _ in throw HcError(kind: "pair", message: "bad token") }
        XCTAssertEqual(model.host, before)
        XCTAssertEqual(model.connection, .disconnected("bad token"))
        XCTAssertNil(HostKeyTrust.trusted("mac.ts.net"))
    }
}
