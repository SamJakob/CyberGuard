//
//  SecureStorageCKDelegate.swift
//  Runner
//
//  Created by Sam M. on 4/9/23.
//

import Foundation

import CryptoKit
import LocalAuthentication

/// The dictionary key (account name) for the user's private key.
let kDefaultPKKey: String = "CGA_DEFAULT_PRIVATE_KEY"

@objc(CGAKeyExistsStatus) public enum KeyExistsStatus: Int { case found = 0, notFound = 1 }
@objc(CGAKeyExistsStatusWrapper) public class KeyExistsStatusWrapper: NSObject {
    /// The status of the key exists query. Is ``KeyExistsStatus```.found` (`CGAKeyExistsStatusFound`) if the key was found,
    /// otherwise ``KeyExistsStatus```.notFound` (`CGAKeyExistsStatusNotFound`).
    @objc public let status: KeyExistsStatus
    
    fileprivate init(_ status: KeyExistsStatus) {
        self.status = status
    }
}

/// Secure Storage Delegate
/// Permits the CGASecureStorage Objective-C class to delegate secure operations to Swift
/// Allows memory safe code to be written for Secure operations, would have allowed interfacing with CryptoKit, however
/// CryptoKit does not support the necessary encryption functions.
@objc(CGASecureStorageDelegate) public class SecureStorageDelegate : NSObject {
    
    private static let encryptionAlgorithm = SecKeyAlgorithm.eciesEncryptionCofactorX963SHA256AESGCM
    
    /// Checks if the device has a useable secure enclave and that the device is not a simulator.
    /// This is simply a check that ``SecureEnclave.isAvailable`` yields true with a convenient single place to add overrides
    /// such as for the simulator.
    /// - Returns: True, if the secure enclave can be used, or if an override is set. Otherwise, false.
    @objc public class func deviceHasSecureEnclave() -> Bool {
        // If SecureEnclave.isAvailable is reported to be true, and the device is not a simulator.
        // (The version needn't be checked as the minimum deployment version is iOS 13 so the .isAvailable
        // method is always available).
        return TARGET_OS_SIMULATOR == 0 && SecureEnclave.isAvailable
    }
    
    
    /// Check if a key with the specified name exists. Returns a ``KeyExistsStatus``. The wrapper class is necessary for ObjC bridging.
    ///
    /// - Parameter name: The associated name of the key to look up.
    /// - Returns: A ``KeyExistsStatus`` (`.found` if it does exist, otherwise `.notFound`).
    @objc public class func checkKeyExists(name: NSString?) throws -> KeyExistsStatusWrapper {
        return KeyExistsStatusWrapper((try hasKey(name: (name as? String) ?? kDefaultPKKey)) ? .found : .notFound)
    }
    
    /// Generates an encryption key that is protected by the secure enclave and susequently stored in the keychain.
    /// The encryption key is associated with the specified name (which should be unique).
    ///
    /// - Parameter name: The associated name of the key.
    /// - Parameter error: If an error occurs, this is the error that is returned.
    @objc public class func generateKey(name: NSString?, overwriteIfExists: Bool = false) async throws {
        // Don't generate anything if the key exists unless `overwriteIfExists` is true.
        if (!overwriteIfExists) {
            if try hasKey(name: (name as? String) ?? kDefaultPKKey) {
                return
            }
        }
        
        /// The generic error returned if generating the key fails. We don't want to return too much information about this process
        /// as a general principle to avoid oracle attacks.
        let generateKeyError = NSError(domain: "com.samjakob.CyberGuard", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "We couldn't generate and store the data encryption key.",
        ])
        
        /// The authentication context used to create the encryption key.
        let authContext = try! await createAuthContext(
            reason: "Set up data encryption",
            fallbackTitle: "Enter your device password to set up data encryption"
        )
        
        // Create the private key access control set.
        
        let privateKeyAccessControl = SecAccessControlCreateWithFlags(
            nil,    // Use default allocator
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,    // Require password to be set, and tied to the device.
            deviceHasSecureEnclave()
                ? [.biometryAny, .privateKeyUsage]              // Require biometrics and permit private key usage.
                : [.biometryAny],                               // .privateKeyUsage is only for Secure Enclave.
            nil
        )
        
        if privateKeyAccessControl == nil {
            throw generateKeyError
        }
        
        // Generate the encryption keys
        
        /// Parameters that override those specified to SecKeyCreateRandomKey when a Secure Enclave is present.
        let secureEnclaveParameters = [
            kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
            
            kSecPrivateKeyAttrs: [
                kSecAttrIsPermanent: true,
                kSecAttrApplicationTag: getKeyTagForName((name as? String ?? kDefaultPKKey)),
                kSecUseAuthenticationContext: authContext,
                kSecAttrAccessControl: privateKeyAccessControl!,
            ].stringDictionary,
            
            // The only supported types for the Secure Enclave.
            // These will override the existing parameters for key type or size in bits.
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits: 256,
        ].stringDictionary
        
        guard let privateKey = SecKeyCreateRandomKey([
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits: 256,
        ].cfDictionary(with: deviceHasSecureEnclave() ? secureEnclaveParameters : nil), nil) else {
            throw generateKeyError
        }
        
        // Check that a public key can be generated.
        guard SecKeyCopyPublicKey(privateKey) != nil else {
            throw generateKeyError
        }
        
        // Save the private key into the keychain.
        do {
            try storeKey(privateKey, name: (name as? String) ?? kDefaultPKKey, singleton: true)
        } catch {
            throw generateKeyError
        }
    }
    
    @objc public class func deleteKey(name: NSString?) throws {
        do {
            try deleteExistingKeys(name: (name as? String) ?? kDefaultPKKey, failSilently: false)
        } catch let baseKeyError {
            throw NSError(domain: "com.samjakob.CyberGuard", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "We couldn't delete the data encryption key. \(baseKeyError.localizedDescription)",
            ])
        }
    }
    
    @objc public class func encrypt(key: NSString?, data: NSData) throws -> NSData {
        // Look up the enclave-wrapped private key in the keychain.
        let enclaveKey: SecKey
        
        do {
            enclaveKey = try loadKey(name: (key as? String) ?? kDefaultPKKey)
        } catch let keyRetrievalError {
            throw NSError(domain: "com.samjakob.CyberGuard", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "We couldn't fetch the encryption key. \(keyRetrievalError.localizedDescription)",
            ])
        }
        
        do {
            guard
                let enclavePublicKey: SecKey = SecKeyCopyPublicKey(enclaveKey),
                let encryptedValue = SecKeyCreateEncryptedData(enclavePublicKey, encryptionAlgorithm, data as CFData, nil) as Data?
            else {
                throw EncryptionDecryptionError(message: "Encryption failed.")
            }
            
            return encryptedValue as NSData;
        } catch let encryptionError {
            throw NSError(domain: "com.samjakob.CyberGuard", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "We failed to encrypt the data. \(encryptionError.localizedDescription)",
            ])
        }
    }
    
    @objc public class func decrypt(key: NSString?, data: NSData) async throws -> NSData {
        // Look up the enclave-wrapped key in the keychain.
        let enclaveKey: SecKey
        
        do {
            enclaveKey = try loadKey(name: (key as? String) ?? kDefaultPKKey)
        } catch let keyRetrievalError {
            throw NSError(domain: "com.samjakob.CyberGuard", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "We couldn't fetch the decryption key. \(keyRetrievalError.localizedDescription)",
            ])
        }
                
        do {
            guard let decryptedValue = SecKeyCreateDecryptedData(enclaveKey, encryptionAlgorithm, data as CFData, nil) as Data? else {
                throw EncryptionDecryptionError(message: "Decryption failed.")
            }
                        
            return decryptedValue as NSData;
        } catch let decryptionError {
            throw NSError(domain: "com.samjakob.CyberGuard", code: 5, userInfo: [
                NSLocalizedDescriptionKey: "We failed to decrypt the data. \(decryptionError.localizedDescription)",
            ])
        }
    }
    
    // MARK: Private Helpers
    
    private class func createAuthContext(
        reason: String = "Please authenticate...",
        fallbackTitle: String?
    ) async throws -> LAContext {
        // Create a Local Authentication context to control specifics about how authentication
        // works.
        let authContext = LAContext()
        
        // Permit a lock screen (and ONLY a lock screen) authentication to cause the application
        // to be unlocked for up to 5 seconds.
        authContext.touchIDAuthenticationAllowableReuseDuration = 5
        
        // Add localized fallback title that explains the purpose of entering the password.
        // (Users are going to have more resistance to entering a password versus biometric
        // authentication.)
        if (fallbackTitle != nil) { authContext.localizedFallbackTitle = fallbackTitle! }
        
        // Add additional contextual information.
        authContext.localizedReason = reason
        
        return authContext
    }
    
}

protocol DictionaryCFConvertables {
    var stringDictionary: [String: Any] { get }
    var cfDictionary: CFDictionary { get }
    func cfDictionary(with: [String: Any]?) -> CFDictionary
    func cfDictionary(with: [CFString: Any]?) -> CFDictionary
}

extension Dictionary<CFString, Any> : DictionaryCFConvertables {
    
    var stringDictionary: [String : Any] {
        return self as [String: Any]
    }
    
    var cfDictionary: CFDictionary {
        return self.stringDictionary as CFDictionary
    }
    
    func cfDictionary(with: [String : Any]? = nil) -> CFDictionary {
        var result = self as [String: Any]
        if (with != nil) { result.merge(with!) { (_, new) in new } }
        return result as [String: Any] as CFDictionary
    }
    
    func cfDictionary(with: [CFString : Any]? = nil) -> CFDictionary {
        var result = self as [CFString: Any]
        if (with != nil) { result.merge(with!) { (_, new) in new } }
        return result as [String: Any] as CFDictionary
    }
    
}
