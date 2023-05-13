package com.samjakob.cyberguard.errors;

import androidx.annotation.NonNull;

public class MissingSecureStorageDelegateError extends SecureStorageDelegateError {

    public MissingSecureStorageDelegateError() {
        super(null, null);
    }

    public MissingSecureStorageDelegateError(String message) {
        super(message, null);
    }

    public MissingSecureStorageDelegateError(Exception ex) {
        super("There is no secure storage environment on the device.", ex);
    }

    @NonNull
    @Override
    public String getMessage() {
        return super.getMessage();
    }
}
