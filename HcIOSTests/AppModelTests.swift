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
}
