package com.samjakob.cyberguard.platform.secure_storage_delegate;

import android.content.Context;

import androidx.annotation.Nullable;
import androidx.annotation.NonNull;

import io.flutter.plugin.common.MethodChannel;

public abstract class SecureStorageDelegate {
    public static final String DEFAULT_KEY_ALIAS = "CGA_DEFAULT_PRIVATE_KEY";

    public static String byNameOrDefault(@Nullable String name) {
        if (name == null) return DEFAULT_KEY_ALIAS;
        else return name;
    }

    /**
     * The MainActivity context, usable for calls into the SDK.
     */
    final Context context;

    public SecureStorageDelegate(Context context) {
        this.context = context;
    }

    @NonNull
    public abstract String getDelegateName();
    @NonNull
    public abstract String getEncryptionSchemeName();

    @NonNull
    public abstract String getStorageLocation();
    public abstract void generateKey(@Nullable String name, boolean overwriteIfExists);
    public abstract void deleteKey(@Nullable String name);
    public abstract byte[] encrypt(@Nullable String keyName, byte[] data);
    public abstract void decrypt(@Nullable String keyName, byte[] data, MethodChannel.Result result);


    // Package-Private Methods

    abstract boolean hasKey(String name);

}
