import XCTest
@testable import HcIOS

final class SentLines: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [[String: Any]] = []

    func append(_ data: Data) {
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        lock.lock()
        items.append(object)
        lock.unlock()
    }

    var all: [[String: Any]] {
        lock.lock()
        defer { lock.unlock() }
        return items
    }
}

final class RPCLinkTests: XCTestCase {
    private func waitFor(_ sent: SentLines, count: Int) async throws {
        for _ in 0..<200 where sent.all.count < count {
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTAssertEqual(sent.all.count, count)
    }

    func testCallSendsRequestAndResolvesResponseSplitAcrossChunks() async throws {
        let link = RPCLink()
        let sent = SentLines()
        await link.attach { sent.append($0) }

        async let result = link.call("terminal.read", ["terminal": "t1"])
        try await waitFor(sent, count: 1)

        let request = sent.all[0]
        XCTAssertEqual(request["jsonrpc"] as? String, "2.0")
        XCTAssertEqual(request["method"] as? String, "terminal.read")
        XCTAssertEqual((request["params"] as? [String: Any])?["terminal"] as? String, "t1")
        let id = try XCTUnwrap(request["id"] as? Int)

        await link.feed(Data("{\"id\":\(id),\"jsonrpc\":\"2.0\",\"res".utf8))
        await link.feed(Data("ult\":{\"text\":\"hi\"}}\n".utf8))

        let value = try await result as? [String: Any]
        XCTAssertEqual(value?["text"] as? String, "hi")
    }

    func testResponsesMatchedByID() async throws {
        let link = RPCLink()
        let sent = SentLines()
        await link.attach { sent.append($0) }

        async let first = link.call("a")
        async let second = link.call("b")
        try await waitFor(sent, count: 2)

        let ids = Dictionary(uniqueKeysWithValues: sent.all.map { ($0["method"] as! String, $0["id"] as! Int) })
        await link.feed(Data("{\"id\":\(ids["b"]!),\"result\":\"B\"}\n{\"id\":\(ids["a"]!),\"result\":\"A\"}\n".utf8))

        let a = try await first as? String
        let b = try await second as? String
        XCTAssertEqual(a, "A")
        XCTAssertEqual(b, "B")
    }

    func testErrorMapsKind() async throws {
        let link = RPCLink()
        let sent = SentLines()
        await link.attach { sent.append($0) }

        async let result = link.call("terminal.get", ["terminal": "t404"])
        try await waitFor(sent, count: 1)
        let id = sent.all[0]["id"] as! Int
        await link.feed(Data("{\"id\":\(id),\"error\":{\"code\":-32000,\"message\":\"no such terminal\",\"data\":{\"kind\":\"not_found\"}}}\n".utf8))

        do {
            _ = try await result
            XCTFail("expected an error")
        } catch let error as HcError {
            XCTAssertEqual(error.kind, "not_found")
            XCTAssertEqual(error.message, "no such terminal")
        }
    }

    func testNotificationsRoutedAndGarbageIgnored() async throws {
        let received = SentLines()
        let link = RPCLink { object in
            received.append(try! JSONSerialization.data(withJSONObject: object))
        }
        await link.feed(Data("not json\n\n{\"jsonrpc\":\"2.0\",\"method\":\"event\",\"params\":{\"seq\":4}}\n".utf8))
        XCTAssertEqual(received.all.count, 1)
        XCTAssertEqual(received.all.first?["method"] as? String, "event")
    }

    func testCloseFailsPendingAndLaterCalls() async throws {
        let link = RPCLink()
        let sent = SentLines()
        await link.attach { sent.append($0) }

        async let result = link.call("terminal.list")
        try await waitFor(sent, count: 1)
        await link.close(HcError(kind: "closed", message: "gone"))

        do {
            _ = try await result
            XCTFail("expected an error")
        } catch let error as HcError {
            XCTAssertEqual(error.kind, "closed")
        }
        do {
            _ = try await link.call("hello")
            XCTFail("expected an error")
        } catch let error as HcError {
            XCTAssertEqual(error.kind, "closed")
        }
    }

    func testReadyWaitsForAttach() async throws {
        let link = RPCLink()
        let waiter = Task { try await link.ready() }
        try await Task.sleep(for: .milliseconds(20))
        await link.attach { _ in }
        try await waiter.value
    }
}
