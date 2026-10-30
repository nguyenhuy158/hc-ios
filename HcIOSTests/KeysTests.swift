import XCTest
@testable import HcIOS

final class KeysTests: XCTestCase {
    private let keyLine = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAjDotcpFM/o24CH6PWXsSr5KuBS9hwIIvQxdx7EDU/y"
    private let otherLine = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK7v1mQx3pWJ0yq9rT2nZ5fH8cLdE4sGbV6uY1oN3aRk"
    private let host = "unit-test-\(UUID().uuidString)"

    override func tearDown() {
        HostKeyTrust.forget(host)
    }

    func testFingerprintMatchesSshKeygen() {
        XCTAssertEqual(HostKeyTrust.fingerprint(keyLine), "SHA256:EiQ0nqBe1Gj7A88IMQMKF0l0npBESArXRnhiVchK3hw")
        XCTAssertEqual(HostKeyTrust.fingerprint(keyLine + " comment"), "SHA256:EiQ0nqBe1Gj7A88IMQMKF0l0npBESArXRnhiVchK3hw")
        XCTAssertEqual(HostKeyTrust.fingerprint("garbage"), "?")
    }

    func testUnknownHostKeyIsRejectedWithoutPrevious() {
        XCTAssertThrowsError(try HostKeyTrust.check(host: host, keyLine: keyLine)) { error in
            let e = error as? HostKeyError
            XCTAssertEqual(e?.keyLine, keyLine)
            XCTAssertEqual(e?.fingerprint, "SHA256:EiQ0nqBe1Gj7A88IMQMKF0l0npBESArXRnhiVchK3hw")
            XCTAssertNil(e?.previousFingerprint)
        }
    }

    func testTrustedHostKeyPasses() {
        HostKeyTrust.trust(host, keyLine: keyLine)
        XCTAssertNoThrow(try HostKeyTrust.check(host: host, keyLine: keyLine))
    }

    func testChangedHostKeyIsRejectedWithPrevious() {
        HostKeyTrust.trust(host, keyLine: keyLine)
        XCTAssertThrowsError(try HostKeyTrust.check(host: host, keyLine: otherLine)) { error in
            let e = error as? HostKeyError
            XCTAssertEqual(e?.previousFingerprint, "SHA256:EiQ0nqBe1Gj7A88IMQMKF0l0npBESArXRnhiVchK3hw")
            XCTAssertEqual(e?.fingerprint, HostKeyTrust.fingerprint(otherLine))
        }
    }

    func testForgetRemovesTrust() {
        HostKeyTrust.trust(host, keyLine: keyLine)
        HostKeyTrust.forget(host)
        XCTAssertNil(HostKeyTrust.trusted(host))
    }

    func testPublicKeyLineIsValidAndStable() throws {
        let line = KeyStore.publicKeyLine(comment: "test")
        let parts = line.split(separator: " ")
        XCTAssertEqual(parts.count, 3)
        XCTAssertEqual(parts[0], "ssh-ed25519")
        XCTAssertEqual(parts[2], "test")

        let blob = try XCTUnwrap(Data(base64Encoded: String(parts[1])))
        func readString(_ data: Data, at offset: Int) -> (Data, Int) {
            let length = data[offset..<offset + 4].reduce(0) { $0 << 8 | Int($1) }
            return (data[offset + 4..<offset + 4 + length], offset + 4 + length)
        }
        let (type, next) = readString(blob, at: blob.startIndex)
        let (key, end) = readString(blob, at: next)
        XCTAssertEqual(String(data: type, encoding: .utf8), "ssh-ed25519")
        XCTAssertEqual(key.count, 32)
        XCTAssertEqual(end, blob.endIndex)

        XCTAssertEqual(KeyStore.publicKeyLine(comment: "test"), line)
    }
}
