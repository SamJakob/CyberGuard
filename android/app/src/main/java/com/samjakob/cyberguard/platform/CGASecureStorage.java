package com.samjakob.cyberguard.platform;

import static com.samjakob.cyberguard.utils.PlatformHelpers.checkIfSimulator;

import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.provider.Settings;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.biometric.BiometricManager;

import com.samjakob.cyberguard.BuildConfig;
import com.samjakob.cyberguard.MainActivity;
import com.samjakob.cyberguard.errors.MissingSecureStorageDelegateError;
import com.samjakob.cyberguard.errors.SecureStorageDelegateError;
import com.samjakob.cyberguard.platform.secure_storage_delegate.EnhancedSecureStorageDelegate;
import com.samjakob.cyberguard.platform.secure_storage_delegate.EnhancedSecurityStorageStatus;
import com.samjakob.cyberguard.platform.secure_storage_delegate.SecureStorageDelegate;
import com.samjakob.cyberguard.platform.secure_storage_delegate.scheme.EncryptionSchemeFactory;
import com.samjakob.cyberguard.platform.secure_storage_delegate.scheme.HybridRSAEncryption;

import org.jetbrains.annotations.NotNull;

import java.security.KeyStore;
import java.util.HashMap;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Messenger instance for the secure storage platform channel.
 */
public class CGASecureStorage {

    /** The Flutter Platform Channel name for the Secure Storage implementation. */
    private static final String SECURE_STORAGE_CHANNEL = "com.samjakob.cyberguard/secure_storage";

    /**
     * The current version of the platform channel specification implemented by this
     * implementation.
     */
    private static final int SECURE_STORAGE_IMPL_VERSION = 1;

    /**
     * Whether the current device has enhanced security.
     */
    private final EnhancedSecurityStorageStatus enhancedSecurityStatus;

    /**
     * The error or warning message for the enhanced security status of the device.
     */
    private final String enhancedSecurityWarningMessage;

    /**
     * The SecureStorageDelegate responsible for handling storage of
     * secure data.
     */
    @Nullable
    private final SecureStorageDelegate secureStorageDelegate;

    private static boolean isInitialized = false;
    private static void ensureInitialized() {
        // Don't initialize if already initialized.
        if (isInitialized) return;

        // Initialize the CyberGuard encryption schemes.
        HybridRSAEncryption.registerScheme();
//        HybridECEncryption.registerScheme();

        isInitialized = true;
    }

    public CGASecureStorage(boolean hasEnhancedSecurity, Context context, MainActivity mainActivity) {
        ensureInitialized();

        SecureStorageDelegate currentSecureStorageDelegate = null;
        String storageDelegateWarning = null;

        try {
            // Attempt to use the EnhancedSecureStorageDelegate if hasEnhancedSecurity
            // is true.
            if (hasEnhancedSecurity) {
                KeyStore appKeyStore;

                try {
                    appKeyStore = KeyStore.getInstance("AndroidKeyStore");
                    appKeyStore.load(null);
                } catch (Exception ex) {
                    throw new MissingSecureStorageDelegateError("We couldn't access the app encryption data.");
                }

                // Select the strongest eligible encryption scheme for the current device.
                EncryptionSchemeFactory.EncryptionSchemeChoice encryptionSchemeChoice
                        = EncryptionSchemeFactory.getEligibleScheme(context, appKeyStore);

                storageDelegateWarning = encryptionSchemeChoice.message;

                // Assuming a valid encryption scheme was found, attempt to start
                // an enhanced secure storage delegate.
                if (encryptionSchemeChoice.scheme != null) {
                    try {
                        currentSecureStorageDelegate = new EnhancedSecureStorageDelegate(
                                context,
                                mainActivity,
                                encryptionSchemeChoice.scheme,
                                appKeyStore
                        );
                    } catch (MissingSecureStorageDelegateError ex) {
                        storageDelegateWarning = ex.getMessage();
                    }
                }
            }
        } catch (Exception ex) {
            if (BuildConfig.DEBUG) ex.printStackTrace();
        }

        // If the device has enhanced security and a registered delegate, indicate that
        // enhanced secure storage is available.
        if (hasEnhancedSecurity && currentSecureStorageDelegate != null) {
            // If there is a warning, reflect this in the status.
            // Otherwise show that it is available.
            if (storageDelegateWarning != null) {
                enhancedSecurityStatus = EnhancedSecurityStorageStatus.WARNING;
            } else {
                enhancedSecurityStatus = EnhancedSecurityStorageStatus.AVAILABLE;
            }
        }
        // Otherwise indicate that there is an error preventing enhanced security from
        // being enabled.
        else {
            enhancedSecurityStatus = EnhancedSecurityStorageStatus.ERROR;
        }

        // Assign the warning message.
        enhancedSecurityWarningMessage = storageDelegateWarning;

        // Assign the secure storage delegate.
        this.secureStorageDelegate = currentSecureStorageDelegate;
    }

    public void handle(MethodCall call, MethodChannel.Result result) {
        switch (call.method) {
            case "ping": {
                HashMap<String, Object> response = new HashMap<>();
                // Useful for simple tests to ensure the platform channel is
                // available.
                response.put("ping", "pong");

                response.put("is_simulator", checkIfSimulator());
                response.put("platform", "Android");
                response.put("platform_version", String.format(
                    "%s (SDK %s)",
                    Build.VERSION.RELEASE,
                    Build.VERSION.SDK_INT
                ));

                response.put("version", SECURE_STORAGE_IMPL_VERSION);
                response.put("has_enhanced_security", enhancedSecurityStatus.code);

                if (secureStorageDelegate != null) {
                    response.put("storage_encryption_delegate", secureStorageDelegate.getDelegateName());
                    response.put("storage_encryption_delegate_scheme", secureStorageDelegate.getEncryptionSchemeName());
                    if (secureStorageDelegate.hasAdditionalData()) {
                        response.put("storage_encryption_delegate_metadata", secureStorageDelegate.getAdditionalData());
                    }
                }

                if (enhancedSecurityWarningMessage != null) {
                    response.put("enhanced_security_warning", enhancedSecurityWarningMessage);
                }

                result.success(response);
                break;
            }

            case "enhancedSecurityStatus": {
                HashMap<String, Object> response = new HashMap<>();
                response.put("status", enhancedSecurityStatus.code);
                response.put("error", enhancedSecurityWarningMessage);
                result.success(response);
                break;
            }
        }

        // The remaining method calls require a secure storage delegate
        // to be registered.
        if (secureStorageDelegate == null) throw new MissingSecureStorageDelegateError();

        try {
            switch (call.method) {
                case "getStorageLocation": {
                    result.success(secureStorageDelegate.getStorageLocation());
                    break;
                }

                case "generateKey": {
                    String name = call.argument("name");
                    boolean overwriteIfExists = Boolean.TRUE.equals(call.argument("overwriteIfExists"));

                    secureStorageDelegate.generateKey(name, overwriteIfExists);
                    result.success(null);
                    break;
                }
                case "deleteKey": {
                    String name = call.argument("name");

                    secureStorageDelegate.deleteKey(name);
                    result.success(null);
                    break;
                }
                case "encrypt": {
                    String name = call.argument("name");
                    byte[] data = call.argument("data");

                    result.success(secureStorageDelegate.encrypt(name, data));
                    break;
                }
                case "decrypt": {
                    String name = call.argument("name");
                    byte[] data = call.argument("data");

                    secureStorageDelegate.decrypt(name, data, result);
                    break;
                }
            }
        } catch (SecureStorageDelegateError ex) {
            result.error(
            "ERR_SECURE_DELEGATE",
            "There was a problem whilst performing the secure operation.",
                ex.getMessage()
            );
        }
    }

    /**
     * Registers a CGASecureStorage instance to handle platform requests from Flutter.
     * Additionally, this checks for 'enhanced security', which on Android refers to
     * the presence of a Strongbox or TEE implementation.
     *
     * @param flutterEngine The engine to handle platform channel messages from.
     * @param context       The Application or MainActivity context.
     * @param mainActivity  The MainActivity.
     */
    public static void createSecureStorageChannel(@NonNull FlutterEngine flutterEngine, @NotNull Context context, MainActivity mainActivity) {
        // Check if the Android device has a hardware security module.
        // Google's first party devices have a specific implementation called the StrongBox
        // KeyStore. Support for this arrived in Android P (9).
        // Other devices, subsequent to Android S (12), received general support for
        // Hardware-backed keystore and the API call for this.
        // After Android S, the Strongbox keystore is guaranteed to work.
        boolean hasTEE = false;

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            hasTEE = context.getPackageManager().hasSystemFeature(PackageManager.FEATURE_STRONGBOX_KEYSTORE, 0);
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            hasTEE |= context.getPackageManager().hasSystemFeature(PackageManager.FEATURE_HARDWARE_KEYSTORE, 0);
        }

        // Assuming there is a trusted execution environment, we'll then check if there
        // are biometrics enrolled to protect the key.
        if (hasTEE) {
            BiometricManager biometricManager = BiometricManager.from(context);
            switch (biometricManager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG)) {
                case BiometricManager.BIOMETRIC_SUCCESS:
                    // App is able to authenticate with biometrics.
                    break;
                case BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED:
                    // Prompt the user to enroll biometrics if we can, but prevent them from
                    // continuing.
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        final Intent fingerprintEnrollIntent = new Intent(Settings.ACTION_BIOMETRIC_ENROLL);
                        fingerprintEnrollIntent.putExtra(Settings.EXTRA_BIOMETRIC_AUTHENTICATORS_ALLOWED,
                                BiometricManager.Authenticators.BIOMETRIC_STRONG);
                        context.startActivity(fingerprintEnrollIntent);
                    }

                    hasTEE = false;
                    break;
                default:
                    // Otherwise biometric support is unavailable.
                    hasTEE = false;
                    break;
            }
        }

        CGASecureStorage secureStorage = new CGASecureStorage(hasTEE, context, mainActivity);
        new MethodChannel(
            flutterEngine.getDartExecutor().getBinaryMessenger(),
            SECURE_STORAGE_CHANNEL
        ).setMethodCallHandler(secureStorage::handle);
    }

}
