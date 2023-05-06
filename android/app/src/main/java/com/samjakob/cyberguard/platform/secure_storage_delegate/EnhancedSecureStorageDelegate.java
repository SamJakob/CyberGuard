package com.samjakob.cyberguard.platform.secure_storage_delegate;

import android.content.Context;
import android.security.keystore.UserNotAuthenticatedException;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.biometric.BiometricManager;
import androidx.biometric.BiometricPrompt;
import androidx.core.content.ContextCompat;

import com.samjakob.cyberguard.MainActivity;
import com.samjakob.cyberguard.errors.MissingSecureStorageDelegateError;
import com.samjakob.cyberguard.errors.SecureStorageDelegateError;
import com.samjakob.cyberguard.platform.secure_storage_delegate.scheme.EncryptionScheme;
import com.samjakob.cyberguard.platform.secure_storage_delegate.scheme.EncryptionSchemeFactory;

import org.jetbrains.annotations.NotNull;

import java.security.KeyStore;
import java.security.KeyStoreException;
import java.security.PrivateKey;
import java.security.PublicKey;
import java.util.Objects;
import java.util.concurrent.Executor;
import java.util.concurrent.atomic.AtomicReference;

import javax.crypto.Cipher;

import io.flutter.plugin.common.MethodChannel;

/**
 * A set of helper methods for the secure storage platform channel.
 * The methods here are responsible for actually performing key
 * generation and management via the TEE or Strongbox.
 * <p>
 * For now, there is no fallback to non-secure hardware.
 */
public class EnhancedSecureStorageDelegate extends SecureStorageDelegate {

    private final EncryptionScheme encryptionScheme;
    private final Executor mainExecutor;
    private final KeyStore appKeyStore;
    private final MainActivity mainActivity;

    public EnhancedSecureStorageDelegate(
        Context context,
        MainActivity mainActivity,
        EncryptionScheme encryptionScheme,
        KeyStore appKeyStore
    ) throws MissingSecureStorageDelegateError {
        super(context);

        // Get an executor that runs on the main thread. This is used for biometric prompts.
        this.mainExecutor = ContextCompat.getMainExecutor(context);

        // Assign the MainActivity of the application.
        this.mainActivity = mainActivity;

        // Assign the encryption scheme to use.
        if (encryptionScheme == null) {
            throw new MissingSecureStorageDelegateError("No valid encryption scheme was found.");
        }

        this.encryptionScheme = encryptionScheme;
        this.appKeyStore = appKeyStore;
    }

    @NonNull
    @Override
    public String getDelegateName() {
        return "EnhancedSecureStorageDelegate";
    }

    @NonNull
    @Override
    public String getEncryptionSchemeName() {
        return EncryptionSchemeFactory.nameFor(encryptionScheme);
    }

    public void generateKey(@Nullable String name, boolean overwriteIfExists) {
        // Set the name of the key to the default application key if it is not already
        // specified.
        name = byNameOrDefault(name);

        deleteKey(name);

        // Skip key generation if the key already exists and overwriteIfExists was
        // not explicitly set.
        if (!overwriteIfExists && hasKey(name)) { return; }

        encryptionScheme.generateKeyPair(mainActivity, context, appKeyStore, name);
    }

    public void deleteKey(@Nullable String name) {
        try {
            appKeyStore.deleteEntry(byNameOrDefault(name));
        } catch (KeyStoreException ex) {
            throw new SecureStorageDelegateError(ex);
        }
    }

    public byte[] encrypt(@Nullable String keyName, byte[] data) {
        keyName = byNameOrDefault(keyName);

        if (!hasKey(keyName)) {
            throw new SecureStorageDelegateError("Failed to locate encryption key.");
        }

        return encryptionScheme.encrypt(appKeyStore, keyName, data);
    }

    public void decrypt(@Nullable String flutterKeyName, byte[] data, MethodChannel.Result flutterResult) {
        // Copy variable to 'effectively final' variable.
        String keyName = byNameOrDefault(flutterKeyName);

        // Ensure the key exists in storage.
        if (!hasKey(keyName)) {
            throw new SecureStorageDelegateError("Failed to retrieve decryption key.");
        }

        // Build the prompt information for the user.
        final String NEGATIVE_BUTTON_TEXT = "Cancel";
        BiometricPrompt.PromptInfo promptInfo = new BiometricPrompt.PromptInfo.Builder()
                .setTitle("Decrypt Data")
                .setSubtitle("Decrypt your CyberGuard data")
                .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                .setNegativeButtonText(NEGATIVE_BUTTON_TEXT)
                .build();

        AtomicReference<BiometricPrompt> biometricPrompt = new AtomicReference<>();
        BiometricPrompt.AuthenticationCallback authCallback = new BiometricPrompt.AuthenticationCallback() {
            private int remainingAttempts = 3;

            @Override
            public void onAuthenticationError(int errorCode, @NonNull CharSequence errString) {
                if (errString.equals(NEGATIVE_BUTTON_TEXT)) {
                    errString = "Decryption was cancelled.";
                }

                // Simply cancel authentication on error.
                biometricPrompt.get().cancelAuthentication();
                flutterResult.error(
                    "ERR_BIOMETRIC_CANCEL",
                    "Biometric decryption was cancelled.",
                    errString
                );
            }

            @Override
            public void onAuthenticationSucceeded(@NonNull BiometricPrompt.AuthenticationResult result) {
                try {
                    if (result.getAuthenticationType() != BiometricPrompt.AUTHENTICATION_RESULT_TYPE_BIOMETRIC) {
                        throw new SecureStorageDelegateError("Invalid biometric type used.");
                    }

                    flutterResult.success(
                        encryptionScheme.decrypt(result.getCryptoObject(), data)
                    );
                } catch (Exception ex) {
                    flutterResult.error(
                        "ERR_DECRYPTION_FAILED",
                        "Failed to decrypt data.",
                        ex.getMessage()
                    );
                }
            }

            @Override
            public void onAuthenticationFailed() {
                // Limit the user to remainingAttempts' initial value, and cancel authentication
                // if they fail more often than that.
                if (remainingAttempts > 1) {
                    super.onAuthenticationFailed();
                    remainingAttempts--;
                } else {
                    biometricPrompt.get().cancelAuthentication();
                }
            }
        };

        try {
            biometricPrompt.set(new BiometricPrompt(mainActivity, mainExecutor, authCallback));
            try {
                biometricPrompt.get().authenticate(
                    promptInfo,
                    encryptionScheme.createCryptoObject(appKeyStore, keyName)
                );
            } catch (UserNotAuthenticatedException ex) {
                // If we get UserNotAuthenticatedException here, it means the user has not
                // yet authenticated with biometrics, which means we cannot load the key.
                // We must therefore ask the user to unlock this with a biometric prompt that
                // does not use a CryptoObject, and *then* have then unlock the key.
                new BiometricPrompt(mainActivity, mainExecutor, new BiometricPrompt.AuthenticationCallback() {
                    @Override
                    public void onAuthenticationSucceeded(@NonNull BiometricPrompt.AuthenticationResult result) {
                        // If the above succeeds, regenerate the biometric prompt and show it to
                        // the user.
                        // The user will see a doubled-up biometric prompt (i.e., they will see the
                        // same visual prompt twice.)
                        mainExecutor.execute(() -> {
                            biometricPrompt.set(new BiometricPrompt(
                                    mainActivity, mainExecutor, authCallback
                            ));

                            try {
                                biometricPrompt.get().authenticate(
                                        promptInfo,
                                        encryptionScheme.createCryptoObject(appKeyStore, keyName)
                                );
                            } catch (Exception ex) {
                                flutterResult.error(
                                    "ERR_DECRYPTION_FAILED",
                                    "Failed to decrypt data.",
                                    ex.getMessage()
                                );
                            }
                        });
                    }
                }).authenticate(promptInfo);
            }
        } catch (SecureStorageDelegateError ex) {
            ex.getUnderlyingException().printStackTrace();
            throw new SecureStorageDelegateError("There was a problem whilst preparing to decrypt data.");
        }
    }

    @Override
    boolean hasKey(@NotNull String name) {
        try {
            return appKeyStore.containsAlias(name);
        } catch (KeyStoreException e) {
            throw new SecureStorageDelegateError(e);
        }
    }

}
