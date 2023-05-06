//
//  PlatformSecurityInterface.swift
//  Runner
//
//  Created by Sam M. on 4/11/23.
//

import Foundation
import CryptoKit

class KeyManipulationError : CGASecurityDelegateError {}

/// Returns the ``kSecAttrApplicationTag`` for a key with the specified name.
/// The name of the key is unique per-key - as is the tag - and thus there is a one-to-one mapping of name to tag and vice versa.
///
/// The mapping is name --> (tag = bundleIdentifier.name).
///
/// - Parameter name: The name of the key.
/// - Returns: The fully qualified tag for the key.
func getKeyTagForName(_ name: String) -> String {
    let bundleIdentifier = CGAUtilities.getBundleIdentifier()
    return "\(bundleIdentifier).\(name)"
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
func deleteExistingKeys(name: String, failSilently: Bool = false) throws {
    // Create a query that finds all the keys for this app.
    let query = [
        kSecClass: kSecClassKey,
        kSecAttrApplicationTag: getKeyTagForName(name),
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
///   - name: The name, which will be converted to a tag, to store the key under (see ``getKeyTagForName(_:)``). Prefer one of the predefined keys in SecureStorageDelegate.
///   - singleton: Whether the key should be a singleton key. If so, ``deleteExistingKeys(account:failSilently:)`` will be called to clear existing keys.
/// - Throws: ``KeyManipulationError`` if there's a problem performing a keychain operation.
func storeKey(_ key: SecKey, name: String, singleton: Bool = false) throws {
    if singleton {
        try deleteExistingKeys(name: name, failSilently: false)
    }
    
    // Package the key as a generic password.
    let query = [
        kSecClass: kSecClassKey,
        kSecAttrApplicationTag: getKeyTagForName(name),
        kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        kSecUseDataProtectionKeychain: true,
        kSecAttrSynchronizable: false,
        kSecValueRef: key
    ] as [String: Any]
    
    // Add the key data to the keychain and inspect the resulting status.
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
        throw KeyManipulationError(message: "We couldn't add the data encryption key to your Keychain. (\(status))")
    }
}

/// Fetches a **single** key from the keychain with the specified name (where the name becomes a key tag and is formulated
/// under the same rules as in ``storeKey(name:account:singleton:)``.
///
/// Returns the located key on success, or throws an exception if the key is missing or couldn't be read.
///
/// - Parameter account: The account name to look for a key under. Prefer a predefined key.
/// - Throws: ``KeyManipulationError`` if accessing the keychain failed, or if the key didn't exist.
/// - Returns: The key.
func loadKey(name: String) throws -> SecKey {
    let bundleIdentifier = CGAUtilities.getBundleIdentifier()
    
    let query = [
        kSecClass: kSecClassKey,
        kSecAttrApplicationTag: "\(bundleIdentifier).\(name)",
        kSecMatchLimit: kSecMatchLimitOne,
        kSecUseDataProtectionKeychain: true,
        kSecReturnRef: true
    ] as [String: Any]
    
    var item: CFTypeRef?
    switch SecItemCopyMatching(query as CFDictionary, &item) {
        case errSecSuccess:
            if item == nil {
                throw KeyManipulationError(message: "There was a problem retrieving the data encryption key.")
            }
            
            return item as! SecKey
        case errSecItemNotFound:
                throw KeyManipulationError(message: "The data encryption key could not be found.")
        case let status: throw KeyManipulationError(message: "There was a problem accessing the data encryption key: \(status.description)")
    }
}

func hasKey(name: String) throws -> Bool {
    let bundleIdentifier = CGAUtilities.getBundleIdentifier()
    
    let query = [
        kSecClass: kSecClassKey,
        kSecAttrApplicationTag: "\(bundleIdentifier).\(name)",
        kSecMatchLimit: kSecMatchLimitOne,
        kSecUseDataProtectionKeychain: true,
        kSecReturnAttributes: true
    ] as [String: Any]
    
    var item: CFTypeRef?
    switch SecItemCopyMatching(query as CFDictionary, &item) {
        case errSecSuccess:
            return true
        case errSecItemNotFound:
            return false
        default: throw KeyManipulationError(message: "There was a problem accessing the Keychain.")
    }
}

