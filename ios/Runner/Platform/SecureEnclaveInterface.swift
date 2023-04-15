//
//  PlatformSecurityInterface.swift
//  Runner
//
//  Created by Sam M. on 4/11/23.
//

import Foundation
import CryptoKit

/// Describes general errors that may occur within the delegate.
class CGADelegateError : NSObject, LocalizedError {

    let message: String;

    override var description: String {
        get {
            return "\(String(describing: type(of: self))): \(message)";
        }
    }

    var errorDescription: String? {
        return description;
    }

    init(message: String) {
        self.message = message
    }

}

class KeyManipulationError : CGADelegateError {}
class EncryptionDecryptionError : CGADelegateError {}

/// Protocol that specifies the conversion interface between a Secure Enclave key and the keychain representation.
/// Source: Apple Documentatin
protocol GenericPasswordConvertible: CustomStringConvertible {
    /// Creates a key from a raw representation.
    init(rawRepresentation data: Data) throws
    
    /// Converts a key to a raw representation of the key.
    var rawRepresentation: Data { get }
}

/// Extension on ``SecureEnclave.P256.KeyAgreement.PrivateKey`` to implement the interface defined by ``GenericPasswordConvertible``.
extension SecureEnclave.P256.KeyAgreement.PrivateKey: GenericPasswordConvertible {
    public var description: String {
        return "[Secure Enclave] P256 key"
    }
    
    init(rawRepresentation data: Data) throws {
        try self.init(dataRepresentation: data)
    }
    
    var rawRepresentation: Data {
        return dataRepresentation
    }
}

/// Deletes any existing keys for the specified account name. Is used by ``storeKey(_:account:singleton:)``
/// when singleton is set to true to ensure no other keys exist after the specified key has been stored.
///
/// The application bundle identifier is prepended to the specified value for `account` as follows:
/// `com.example.my_bundle_identifier.account` where `com.example.my_bundle_identifier` is the bundle
/// identifier and `account` is the account.
///
///
/// - Parameters:
///   - account: The account name under which to look for keys to delete. Should be a predefined key. As noted above, application bundle identifier is prepended to the specified value.
///   - failSilently: If an exception is unnecessary or confusing (e.g., in the case of storeKey), set this to `true` to suppress them (the function will simply exit).
/// - Throws: ``KeyManipulationError`` if accessing or modifying the keychain fails and `failSilently` is `false`.
func deleteExistingKeys(account: String, failSilently: Bool = false) throws {
    let bundleIdentifier = CGAUtilities.getBundleIdentifier()
    
    // Create a query that finds all the keys for this app.
    let query = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrAccount: "\(bundleIdentifier).\(account)",
        kSecAttrService: bundleIdentifier
    ] as [String: Any]
    
    // Then, perform a deletion with the query and inspect the status.
    let status = SecItemDelete(query as CFDictionary)
    
    // If the operation wasn't successful (and it didn't fail because the item wasn't there)
    // then throw the error, provided failSilently is false.
    if (status != errSecSuccess && status != errSecItemNotFound) {
        if (failSilently) {
            return
        } else {
            throw KeyManipulationError(message: "We ran into a problem whilst removing existing keys.")
        }
    }
    
}

/// Stores a key (which has an implementation of the ``GenericPasswordConvertible`` interface) in the keychain.
/// The key is stored under a ``kSecAttrService`` of the application's bundle identifier.
///
/// - Parameters:
///   - key: The key to store in the keychain.
///   - account: The account name to store the key under. Prefer one of the predefined keys.
///   - singleton: Whether the key should be a singleton key. If so, ``deleteExistingKeys(account:failSilently:)`` will be called to clear existing keys.
/// - Throws: ``KeyManipulationError`` if there's a problem performing a keychain operation.
func storeKey<T: GenericPasswordConvertible>(_ key: T, account: String, singleton: Bool = false) throws {
    let bundleIdentifier = CGAUtilities.getBundleIdentifier()
    
    if singleton {
        try deleteExistingKeys(account: account, failSilently: false)
    }
    
    // Package the key as a generic password.
    let query = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrAccount: "\(bundleIdentifier).\(account)",
        kSecAttrService: bundleIdentifier,
        kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        kSecUseDataProtectionKeychain: true,
        kSecAttrSynchronizable: false,
        kSecValueData: key.rawRepresentation
    ] as [String: Any]
    
    // Add the key data to the keychain and inspect the resulting status.
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
        throw KeyManipulationError(message: "We couldn't add the data encryption key to your Keychain.")
    }
}

/// Fetches a **single** key from the keychain with the specified account name (where the account name is formulated
/// under the same rules as in ``storeKey(_:account:singleton:)``.
///
/// Returns the located key on success, or throws an exception if the key is missing or couldn't be read.
///
/// - Parameter account: The account name to look for a key under. Prefer a predefined key.
/// - Throws: ``KeyManipulationError`` if accessing the keychain failed, or if the key didn't exist.
/// - Returns: The key.
func loadKey<T: GenericPasswordConvertible>(account: String) throws -> T {
    let bundleIdentifier = CGAUtilities.getBundleIdentifier()
    
    let query = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrAccount: "\(bundleIdentifier).\(account)",
        kSecAttrService: bundleIdentifier,
        kSecMatchLimit: kSecMatchLimitOne,
        kSecUseDataProtectionKeychain: true,
        kSecReturnData: true
    ] as [String: Any]
    
    var item: CFTypeRef?
    switch SecItemCopyMatching(query as CFDictionary, &item) {
        case errSecSuccess:
            guard let data = item as? Data else {
                throw KeyManipulationError(message: "There was a problem retrieving the data encryption key.")
            }
            return try T(rawRepresentation: data)
        case errSecItemNotFound:
            throw KeyManipulationError(message: "The data encryption key could not be found.")
        case let status: throw KeyManipulationError(message: "There was a problem accessing the data encryption key: \(status.description)")
    }
}

public extension Data {
    private static let hexAlphabet = Array("0123456789abcdef".unicodeScalars)
    func hexStringEncoded() -> String {
        String(reduce(into: "".unicodeScalars) { result, value in
            result.append(Self.hexAlphabet[Int(value / 0x10)])
            result.append(Self.hexAlphabet[Int(value % 0x10)])
        })
    }
}

