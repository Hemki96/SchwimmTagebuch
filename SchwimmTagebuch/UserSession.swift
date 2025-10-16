import Foundation
import SwiftUI
import CryptoKit

enum SessionKeys {
    static let currentUserID = "session.currentUserID"
}

enum PasswordHasher {
    static func hash(_ password: String) -> String {
        let salt = randomSalt()
        let digest = sha256Digest(salt: salt, password: password)
        return salt.base64EncodedString() + ":" + digest.base64EncodedString()
    }

    static func verify(password: String, storedHash: String) -> Bool {
        let components = storedHash.split(separator: ":", maxSplits: 1).map(String.init)
        guard components.count == 2,
              let saltData = Data(base64Encoded: components[0]),
              let storedDigest = Data(base64Encoded: components[1])
        else { return false }
        let digest = sha256Digest(salt: saltData, password: password)
        return digest == storedDigest
    }

    private static func randomSalt() -> Data {
        Data((0..<16).map { _ in UInt8.random(in: 0...255) })
    }

    private static func sha256Digest(salt: Data, password: String) -> Data {
        var message = Data()
        message.append(salt)
        message.append(Data(password.utf8))
        let digest = SHA256.hash(data: message)
        return Data(digest)
    }
}

private struct CurrentUserKey: EnvironmentKey {
    static let defaultValue: AppUser? = nil
}

extension EnvironmentValues {
    var currentUser: AppUser? {
        get { self[CurrentUserKey.self] }
        set { self[CurrentUserKey.self] = newValue }
    }
}

private struct LogoutActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    var logoutAction: (() -> Void)? {
        get { self[LogoutActionKey.self] }
        set { self[LogoutActionKey.self] = newValue }
    }
}
