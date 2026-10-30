import Crypto
import Foundation
import NIOCore
import NIOSSH

struct HostKeyError: Error {
    let host: String
    let keyLine: String
    let fingerprint: String
    let previousFingerprint: String?
}

struct HostKeyTrust {
    private static let defaultsKey = "trustedHostKeys"

    static func trusted(_ host: String) -> String? {
        (UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: String])?[host]
    }

    static func trust(_ host: String, keyLine: String) {
        var all = (UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: String]) ?? [:]
        all[host] = keyLine
        UserDefaults.standard.set(all, forKey: defaultsKey)
    }

    static func forget(_ host: String) {
        var all = (UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: String]) ?? [:]
        all[host] = nil
        UserDefaults.standard.set(all, forKey: defaultsKey)
    }

    static func fingerprint(_ keyLine: String) -> String {
        let parts = keyLine.split(separator: " ")
        guard parts.count >= 2, let blob = Data(base64Encoded: String(parts[1])) else { return "?" }
        let digest = Data(SHA256.hash(data: blob)).base64EncodedString()
        return "SHA256:" + digest.trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }

    static func check(host: String, keyLine: String) throws {
        let saved = trusted(host)
        guard saved != keyLine else { return }
        throw HostKeyError(host: host, keyLine: keyLine, fingerprint: fingerprint(keyLine),
                           previousFingerprint: saved.map(fingerprint))
    }

    struct Validator: NIOSSHClientServerAuthenticationDelegate {
        let host: String

        func validateHostKey(hostKey: NIOSSHPublicKey, validationCompletePromise: EventLoopPromise<Void>) {
            do {
                try HostKeyTrust.check(host: host, keyLine: String(openSSHPublicKey: hostKey))
                validationCompletePromise.succeed(())
            } catch {
                validationCompletePromise.fail(error)
            }
        }
    }
}
