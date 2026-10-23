import Foundation
import CryptoKit

/// Salted SHA-256 PIN hashing. The plain PIN is never written to disk.
/// This is not a password KDF; it only raises the bar for a casual peek at
/// the App Group defaults. For a personal commitment app that is enough.
enum PINCrypto {
    static func makeSalt() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
    }

    static func hash(pin: String, salt: String) -> String {
        let input = Data((salt + pin).utf8)
        let digest = SHA256.hash(data: input)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Set (or replace) the stored PIN.
    static func setPIN(_ pin: String) {
        let salt = makeSalt()
        SharedState.pinSalt = salt
        SharedState.pinHash = hash(pin: pin, salt: salt)
    }

    /// Verify a candidate PIN against the stored hash.
    static func verify(_ candidate: String) -> Bool {
        guard let salt = SharedState.pinSalt, let stored = SharedState.pinHash else {
            return false
        }
        return hash(pin: candidate, salt: salt) == stored
    }

    static func clearPIN() {
        SharedState.pinHash = nil
        SharedState.pinSalt = nil
    }
}
