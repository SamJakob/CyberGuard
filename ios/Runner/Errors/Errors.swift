//
//  Errors.swift
//  Runner
//
//  Created by Sam M. on 4/15/23.
//

import Foundation

/// Describes general errors that may occur within the delegate.
class CGASecurityDelegateError : NSObject, LocalizedError {

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

/// Describes errors that occur during the encryption and decryption process.
class EncryptionDecryptionError : CGASecurityDelegateError {}
