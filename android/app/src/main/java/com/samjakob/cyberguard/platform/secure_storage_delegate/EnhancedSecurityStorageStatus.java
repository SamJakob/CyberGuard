package com.samjakob.cyberguard.platform.secure_storage_delegate;

public enum EnhancedSecurityStorageStatus {
    AVAILABLE(0),
    WARNING(1),
    ERROR(2);

    public final int code;

    EnhancedSecurityStorageStatus(int code) {
        this.code = code;
    }
}
