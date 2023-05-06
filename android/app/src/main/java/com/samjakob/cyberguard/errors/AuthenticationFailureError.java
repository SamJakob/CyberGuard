package com.samjakob.cyberguard.errors;

import androidx.annotation.NonNull;

public class AuthenticationFailureError extends SecureStorageDelegateError {

    private static AuthenticationFailureError badCredential() {
        return new AuthenticationFailureError("Your credentials were invalid.");
    }

    private static AuthenticationFailureError unknownIssue() {
        return new AuthenticationFailureError("An unknown issue occurred.");
    }

    private final String message;

    private AuthenticationFailureError(String message) {
        this.message = message;
    }

    @NonNull
    @Override
    public String getMessage() {
        return message;
    }

}
