//
//  UserPresenceDelegate.swift
//  Runner
//
//  Created by Sam M. on 5/12/23.
//

import Foundation

import LocalAuthentication

/// User Presence Delegate
/// Manages application user presence checks.
@objc(CGAUserPresenceDelegate) public class UserPresenceDelegate : NSObject {
    
    private var context: LAContext?;
    
    /// Uses ``LAContext.canEvaluatePolicy`` to test for the device's abiity to test device
    /// owner authentication with biometrics. Returns a string ON ERROR, otherwise returns nil to
    /// indicate that there are no problems.
    @objc public func checkFunctionality() -> String? {
        var context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return error?.localizedDescription ?? "Your device does not support the features necessary for user presence detection."
        }
        
        return nil
    }
    
    @objc public func cancelVerifyUserPresence() async -> Bool {
        context?.invalidate()
        return true
    }
    
    @objc public func verifyUserPresence() async -> Bool {
        context = LAContext()
        context!.localizedCancelTitle = "Cancel"
        
        do {
            try await context!.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Verify your identity")
            context = nil
            
            return true
        } catch {
            return false
        }
    }
    
}
