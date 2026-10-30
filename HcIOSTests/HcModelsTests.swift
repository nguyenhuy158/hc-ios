import XCTest
@testable import HcIOS

final class HcModelsTests: XCTestCase {
    private func fixture() throws -> [TerminalInfo] {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "terminal-list", withExtension: "json"))
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        return try HcJSON.decode(HcListResult.self, from: object).terminals.map(\.info)
    }

    func testDecodesRealListPayload() throws {
        let terminals = try fixture()
        XCTAssertEqual(terminals.map(\.id), ["t1", "vps/t1", "t9"])
    }

    func testBlockedAgentFromStatus() throws {
        let t1 = try fixture()[0]
        XCTAssertEqual(t1.status, .blocked)
        XCTAssertEqual(t1.program, "claude-code")
        XCTAssertEqual(t1.name, "✳ Claude Code")
        XCTAssertEqual(t1.folder, "/Users/me/work/api/services/farm")
        XCTAssertEqual(t1.since, Date(timeIntervalSince1970: 1_793_371_649.741))
    }

    func testRemoteShellWithoutStatus() throws {
        let remote = try fixture()[1]
        XCTAssertEqual(remote.status, .idle)
        XCTAssertEqual(remote.name, "root / 1")
        XCTAssertEqual(remote.program, "bash")
        XCTAssertEqual(remote.folder, "vps:/root")
        XCTAssertEqual(remote.since, Date(timeIntervalSince1970: 1_793_356_235.453))
    }

    func testErrorCountsAsBlockedAndNameWins() throws {
        let t9 = try fixture()[2]
        XCTAssertEqual(t9.status, .blocked)
        XCTAssertEqual(t9.name, "web-agent")
        XCTAssertEqual(t9.program, "codex")
        XCTAssertEqual(t9.folder, "/Users/me/work/web")
    }

    func testStatusMapping() {
        XCTAssertEqual(TerminalStatus(hcState: "blocked"), .blocked)
        XCTAssertEqual(TerminalStatus(hcState: "error"), .blocked)
        XCTAssertEqual(TerminalStatus(hcState: "working"), .working)
        XCTAssertEqual(TerminalStatus(hcState: "done"), .done)
        XCTAssertEqual(TerminalStatus(hcState: "idle"), .idle)
        XCTAssertEqual(TerminalStatus(hcState: nil), .idle)
        XCTAssertEqual(TerminalStatus(hcState: "something-new"), .idle)
    }

    func testSectionsOrderAndOldestBlockedFirst() throws {
        let sections = TerminalInfo.sections(try fixture())
        XCTAssertEqual(sections.map(\.status), [.blocked, .idle])
        XCTAssertEqual(sections[0].items.map(\.id), ["t9", "t1"])
    }

    func testSectionsSkipEmpty() {
        XCTAssertTrue(TerminalInfo.sections([]).isEmpty)
    }

    func testShortFolder() throws {
        let terminals = try fixture()
        XCTAssertEqual(terminals[0].shortFolder, "services/farm")
        XCTAssertEqual(terminals[1].shortFolder, "vps · /root")
        XCTAssertEqual(terminals[2].shortFolder, "work/web")
    }
}
