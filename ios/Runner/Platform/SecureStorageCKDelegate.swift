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

/// Secure Storage CryptoKit Delegate.
/// Permits the CGASecureStorage Objective-C class to delegate secure operations to Swift
/// Allows memory safe code to be written for Secure operations, would have allowed interfacing with CryptoKit, however
/// CryptoKit does not support the necessary encryption functions.
@objc(CGASecureStorageDelegate) public class SecureStorageDelegate : NSObject {
    
    private static let encryptionAlgorithm = SecKeyAlgorithm.eciesEncryptionCofactorX963SHA256AESGCM
    
    /// Checks if the device has a useable secure enclave. This is simply ensures the device is not a simulator and that
    /// ``SecureEnclave.isAvailable`` yields true.
    /// - Returns: True, if the secure enclave can be used. Otherwise, false.
    @objc public class func deviceHasSecureEnclave() -> Bool {
        // If the device is not a simulator and SecureEnclave.isAvailable is reported
        // to be true.
        // (The version needn't be checked as the minimum deployment version is iOS 13).
        return TARGET_OS_SIMULATOR == 0 && SecureEnclave.isAvailable
    }
    
    /// Generates an encryption key that is protected by the secure enclave and susequently stored in the keychain.
    /// The encryption key is associated with the specified name (which should be unique).
    /// The base64-encodeds public key is returned so that it can be used to encrypt data.
    ///
    /// - Parameter name: The associated name of the key.
    /// - Parameter error: If an error occurs, this is the error that is returned.
    /// - Returns: The corresponding public encryption key to the private one, or nil if there is already one for the specified name.
    @objc public class func generateKey(name: NSString?, error: NSErrorPointer) async -> String? {
        let authContext = try! await createAuthContext(reason: "Set up data encryption", fallbackTitle: "Enter your device password to set up data encryption")
        
        // Generate an (encoded) private key.
        var privateKey: SecureEnclave.P256.KeyAgreement.PrivateKey
        
        do {
            privateKey = try SecureEnclave.P256.KeyAgreement.PrivateKey(
                // Do not use the compact representation. FIPS compliance.
                compactRepresentable: false,
                accessControl: SecAccessControlCreateWithFlags(
                    nil, // Use default allocator.
                    kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,    // Require password to be set, and tied to the device.
                    [.biometryAny, .privateKeyUsage],   // Permit any enrolled biometrics on the device to use the private key.
                    nil // No error handler.
                )!,
                authenticationContext: authContext
            )
        } catch let baseKeyError {
            error?.pointee = NSError(domain: "com.samjakob.CyberGuard", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "We couldn't create a data encryption key. \(baseKeyError.localizedDescription)",
            ])
            
            return nil
        }
        
        // Add the key to the keychain.
        
        do {
            try storeKey(privateKey, account: (name as? String) ?? kDefaultPKKey, singleton: true)
        } catch let baseKeyError {
            error?.pointee = NSError(domain: "com.samjakob.CyberGuard", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "We couldn't store the data encryption key. \(baseKeyError.localizedDescription)",
            ])
            
            return nil
        }
        
        // Return only the public key. The application can then use this to encrypt data, but
        // must make calls to decrypt data.
        return privateKey.publicKey.rawRepresentation.base64EncodedString()
    }
    
    @objc public class func deleteKey(name: NSString?, error: NSErrorPointer) {
        do {
            try deleteExistingKeys(account: (name as? String) ?? kDefaultPKKey, failSilently: false)
        } catch let baseKeyError {
            error?.pointee = NSError(domain: "com.samjakob.CyberGuard", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "We couldn't delete the data encryption key. \(baseKeyError.localizedDescription)",
            ])
        }
    }
    
    @objc public class func encrypt(key: NSString?, data: NSData, error: NSErrorPointer) -> NSData? {
        // Look up the enclave-wrapped key in the keychain.
        let enclaveKey: SecureEnclave.P256.KeyAgreement.PrivateKey
        
        do {
            enclaveKey = try loadKey(account: (key as? String) ?? kDefaultPKKey)
        } catch let keyRetrievalError {
            error?.pointee = NSError(domain: "com.samjakob.CyberGuard", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "We couldn't fetch the encryption key. \(keyRetrievalError.localizedDescription)",
            ])
            
            return nil
        }
        
        do {
            let enclaveSecKey = try toPublicEnclaveSecKey(enclaveKey: enclaveKey.publicKey, error: error)
            
            guard let encryptedValue = SecKeyCreateEncryptedData(enclaveSecKey, encryptionAlgorithm, data as CFData, nil) as Data? else {
                throw EncryptionDecryptionError(message: "Encryption failed.")
            }
            
            return encryptedValue as NSData?;
        } catch let encryptionError {
            error?.pointee = NSError(domain: "com.samjakob.CyberGuard", code: 6, userInfo: [
                NSLocalizedDescriptionKey: "We failed to encrypt the data. \(encryptionError.localizedDescription)",
            ])
            
            return nil
        }
    }
    
    @objc public class func decrypt(key: NSString?, data: NSData, error: NSErrorPointer) async -> NSData? {
        // Look up the enclave-wrapped key in the keychain.
        let enclaveKey: SecureEnclave.P256.KeyAgreement.PrivateKey
        
        do {
            enclaveKey = try loadKey(account: (key as? String) ?? kDefaultPKKey)
        } catch let keyRetrievalError {
            error?.pointee = NSError(domain: "com.samjakob.CyberGuard", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "We couldn't fetch the decryption key. \(keyRetrievalError.localizedDescription)",
            ])
            
            return nil
        }
                
        do {
            let enclaveSecKey: SecKey = try await toPrivateEnclaveSecKey(enclaveKey: enclaveKey, error: error)
            print(try! toPublicEnclaveSecKey(enclaveKey: enclaveKey.publicKey, error: nil))
            
            print(enclaveKey.rawRepresentation)
            print(SecKeyCopyExternalRepresentation(enclaveSecKey, nil) ?? "")
            
            let enclaveSecKeyPublic = SecKeyCopyPublicKey(enclaveSecKey)!
            print(enclaveSecKeyPublic)
            
            print("DECRYPTION 1")
            
            var cfError: Unmanaged<CFError>?
            
            guard let decryptedValue = SecKeyCreateDecryptedData(enclaveSecKey, encryptionAlgorithm, data as CFData, &cfError) as Data? else {
                print("DECRYPTION FAIL \(String(describing: cfError))")
                throw EncryptionDecryptionError(message: "Decryption failed.")
            }
            
            print("DECRYPTION 2")
            
            return decryptedValue as NSData?;
        } catch let decryptionError {
            error?.pointee = NSError(domain: "com.samjakob.CyberGuard", code: 5, userInfo: [
                NSLocalizedDescriptionKey: "We failed to decrypt the data. \(decryptionError.localizedDescription)",
            ])
            
            return nil
        }
    }
    
    private class func toPrivateEnclaveSecKey(enclaveKey: SecureEnclave.P256.KeyAgreement.PrivateKey, error: NSErrorPointer) async throws -> SecKey {
        do {
            // Load the secure enclave as a Security framework SecKey.
            var cfSecKeyCreateError: Unmanaged<CFError>?
            
            guard
                let enclaveSecKey: SecKey = SecKeyCreateWithData(enclaveKey.rawRepresentation as CFData, [
                    kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
                    kSecAttrKeyClass: kSecAttrKeyClassPrivate,
                    kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
                    kSecAttrAccessible: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                    kSecUseAuthenticationContext: try await createAuthContext(
                        reason: "Decrypt data",
                        fallbackTitle: "Enter your device password to decrypt data",
                        mustEvaluate: true
                    ),
                    kSecAttrIsPermanent: true,
                    kSecAttrIsExtractable: false,
                    kSecAttrSynchronizable: false,
                    kSecAttrKeySizeInBits: 256,
                    kSecAttrAccessControl: SecAccessControlCreateWithFlags(
                        nil, // Use default allocator.
                        kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,    // Require password to be set, and tied to the device.
                        [.biometryAny, .privateKeyUsage],   // Permit any enrolled biometrics on the device.
                        &cfSecKeyCreateError
                    )!
                ] as [String: Any] as CFDictionary, nil)
            else {
                throw EncryptionDecryptionError(message: "We found a problem while loading the decryption key.")
            };
            
            if (!SecKeyIsAlgorithmSupported(enclaveSecKey, .decrypt, encryptionAlgorithm) || cfSecKeyCreateError != nil) {
                if (cfSecKeyCreateError != nil) {
                    cfSecKeyCreateError!.release()
                }
                
                throw EncryptionDecryptionError(message: "We found a problem while loading the decryption key.")
            }
            
            return enclaveSecKey
        } catch let keyLoadError {
            throw NSError(domain: "com.samjakob.CyberGuard", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "We failed to load the decryption key. \(keyLoadError.localizedDescription)",
            ])
        }
    }
    
    private class func toPublicEnclaveSecKey(enclaveKey: P256.KeyAgreement.PublicKey, error: NSErrorPointer) throws -> SecKey {
        do {
            // Load the secure enclave as a Security framework SecKey.
            guard
                let enclaveSecKey: SecKey = SecKeyCreateWithData(enclaveKey.x963Representation as CFData, [
                    kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
                    kSecAttrKeyClass: kSecAttrKeyClassPublic,
                    kSecAttrKeySizeInBits: 256
                ] as [String: Any] as CFDictionary, nil),
                SecKeyIsAlgorithmSupported(enclaveSecKey, .encrypt, encryptionAlgorithm)
            else {
                throw EncryptionDecryptionError(message: "We failed to load the encryption key.")
            };
            
            return enclaveSecKey
        } catch let keyLoadError {
            throw NSError(domain: "com.samjakob.CyberGuard", code: 7, userInfo: [
                NSLocalizedDescriptionKey: "We failed to load the encryption key. \(keyLoadError.localizedDescription)",
            ])
        }
    }
    
    private class func createAuthContext(reason: String?, fallbackTitle: String?, mustEvaluate: Bool = false) async throws -> LAContext {
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
        if (reason != nil) { authContext.localizedReason = reason! }
        
        if mustEvaluate {
            let evaluateAccessControlSuccess = (try await authContext.evaluateAccessControl(SecAccessControlCreateWithFlags(
                nil, // Use default allocator.
                kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,    // Require password to be set, and tied to the device.
                .biometryAny,   // Permit any enrolled biometrics on the device.
                nil // No error handler.
            )!, operation: .useKeyDecrypt, localizedReason: authContext.localizedReason))
            
            if (!evaluateAccessControlSuccess) {
                throw EncryptionDecryptionError(message: "Failed to authenticate biometrics.")
            }
        }
        
        return authContext
    }
    
}
