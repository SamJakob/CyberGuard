package com.samjakob.cyberguard.errors;

import androidx.annotation.NonNull;

public class SecureStorageDelegateError extends RuntimeException {

    @NonNull
    private final String message;

    private final Exception underlyingException;

    public SecureStorageDelegateError() {
        this(null, null);
    }

    public SecureStorageDelegateError(String message) {
        this(message, null);
    }

    public SecureStorageDelegateError(Exception underlyingException) {
        this(null, underlyingException);
    }

    public SecureStorageDelegateError(String message, Exception underlyingException) {
        this.message = message != null
                ? message
                : "There was a problem whilst preparing the secure storage environment";
        this.underlyingException = underlyingException;
    }

    @NonNull
    @Override
    public String getMessage() {
        return message;
    }

    public Exception getUnderlyingException() {
        return underlyingException;
    }
}
