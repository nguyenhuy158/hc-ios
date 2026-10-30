import Crypto
import Foundation
import Security

enum KeyStore {
    private static let service = "dev.nguyenhuy158.hcios.ssh"
    private static let account = "ed25519"

    static func privateKey() throws -> Curve25519.Signing.PrivateKey {
        if let data = load() {
            return try Curve25519.Signing.PrivateKey(rawRepresentation: data)
        }
        let key = Curve25519.Signing.PrivateKey()
        try save(key.rawRepresentation)
        return key
    }

    static func publicKeyLine(comment: String = "hc-ios@iphone") -> String {
        guard let key = try? privateKey() else { return "" }
        var blob = Data()
        blob.appendSSHString(Data("ssh-ed25519".utf8))
        blob.appendSSHString(key.publicKey.rawRepresentation)
        let line = "ssh-ed25519 \(blob.base64EncodedString()) \(comment)"
        UserDefaults.standard.set(line, forKey: "publicKey")
        return line
    }

    private static func load() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    private static func save(_ data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw HcError(kind: "keychain", message: "Could not save the SSH key (\(status)).")
        }
    }
}

extension Data {
    mutating func appendSSHString(_ bytes: Data) {
        var length = UInt32(bytes.count).bigEndian
        append(Data(bytes: &length, count: 4))
        append(bytes)
    }
}
