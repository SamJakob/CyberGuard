package com.samjakob.cyberguard.platform.secure_storage_delegate.scheme;

import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyInfo;
import android.security.keystore.KeyProperties;
import android.security.keystore.UserNotAuthenticatedException;

import androidx.annotation.NonNull;
import androidx.biometric.BiometricPrompt;

import com.samjakob.cyberguard.BuildConfig;
import com.samjakob.cyberguard.MainActivity;
import com.samjakob.cyberguard.errors.SecureStorageDelegateError;

import java.security.KeyFactory;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.KeyStore;
import java.security.NoSuchAlgorithmException;
import java.security.PrivateKey;
import java.security.PublicKey;
import java.util.Objects;

import javax.crypto.BadPaddingException;
import javax.crypto.Cipher;
import javax.crypto.IllegalBlockSizeException;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;

public class FallbackAESEncryption implements EncryptionScheme {

    public static final String NAME = "FallbackAESEncryption";

    private static final String CIPHER_TRANSFORMATION = "AES/CBC/PKCS7Padding";

    public static void registerScheme() {
        EncryptionSchemeFactory.register(
            NAME, FallbackAESEncryption.class,
            // Should work on every device.
            FallbackAESEncryption::checkEligibility,
            EncryptionSchemeFactory.SchemeStrength.FALLBACK
        );
    }

    private static String checkEligibility(Context context, KeyStore appKeyStore) {
        // Attempt to initialize a KeyPair generator to check the algorithm.
        try {
            KeyGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_AES,
                appKeyStore.getProvider()
            );
        } catch (NoSuchAlgorithmException ex) {
            return "Your device does not support any secure encryption algorithm.";
        }

        // Run an encryption test.
        try {
            new FallbackAESEncryption().performEncryptionTest(context, appKeyStore);
        } catch (SecureStorageDelegateError ex) {
            return ex.getMessage();
        }

        // Otherwise, no issues.
        return null;
    }

    @Override
    public void generateKeyPair(MainActivity mainActivity, Context context, KeyStore appKeyStore, String name) {
        KeyGenParameterSpec.Builder keySpecBuilder = new KeyGenParameterSpec.Builder(
                name, KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT
        )
            // Require user authentication for usage of the key.
            .setUserAuthenticationRequired(true)
            // Also handled by setUserAuthenticationParameters for Android R+.
            .setUserAuthenticationValidityDurationSeconds(-1)
            // Use CBC block mode.
            .setBlockModes(KeyProperties.BLOCK_MODE_CBC)
            // Use PKCS7 padding.
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_PKCS7)
            ;

        // On supported devices, signal that new biometrics being enrolled should not
        // trigger invalidation of the key (we trust the user's device in the current
        // security model and an existing biometric authentication would be required
        // to enroll a new one).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            keySpecBuilder = keySpecBuilder.setInvalidatedByBiometricEnrollment(false);
        }

        // On supported devices, signal that usage of the key requires the device to
        // be unlocked.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            keySpecBuilder = keySpecBuilder.setUnlockedDeviceRequired(true);
        }

        // On supported devices, more precisely set the requirement put in place by
        // setUserAuthenticationValidityDurationSeconds, that strong biometric security
        // must be used every time the key is used.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            keySpecBuilder = keySpecBuilder.setUserAuthenticationParameters(
                // Timeout = 0 requires authentication every time the key is used.
                0,
                KeyProperties.AUTH_BIOMETRIC_STRONG
            );
        }

        // If there is a StrongBox implementation on the device, and the
        // setIsStrongBoxBacked API is supported by the device call
        // setIsStrongBoxBacked to use it.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
                context.getPackageManager().hasSystemFeature(PackageManager.FEATURE_STRONGBOX_KEYSTORE)) {
            keySpecBuilder = keySpecBuilder.setIsStrongBoxBacked(true);
        }

        try {
            KeyGenerator keyGenerator = KeyGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_AES,
                "AndroidKeyStore"
            );

            // Generate the keypair using AndroidKeyStore and the above requirements.
            keyGenerator.init(keySpecBuilder.build());
            SecretKey key = keyGenerator.generateKey();

            // Load the key information to verify that the key meets the necessary
            // standards.
            KeyFactory factory = KeyFactory.getInstance(
                key.getAlgorithm(), "AndroidKeyStore"
            );
            KeyInfo keyInfo = factory.getKeySpec(key, KeyInfo.class);

            // Ensure that the key has been generated securely, preventing its use if it
            // hasn't.
            boolean isSecureKey;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // The key is secure if the key is protected by at least a trusted environment.
                isSecureKey = (keyInfo.getSecurityLevel() >= KeyProperties.SECURITY_LEVEL_TRUSTED_ENVIRONMENT)
                        // Or, if the exact nature of security is unknown but it is guaranteed to be
                        // SECURITY_LEVEL_TRUSTED_ENVIRONMENT.
                        || keyInfo.getSecurityLevel() == KeyProperties.SECURITY_LEVEL_UNKNOWN_SECURE;
            } else {
                // On older systems fallback to checking isInsideSecureHardware.
                // This has been replaced on newer OS builds by getSecurityLevel.
                isSecureKey = keyInfo.isInsideSecureHardware();
            }

            isSecureKey &= keyInfo.isUserAuthenticationRequirementEnforcedBySecureHardware();

            if (!isSecureKey) {
                throw new SecureStorageDelegateError("Failed to generate a secure key.");
            }
        } catch (Exception ex) {
            throw new SecureStorageDelegateError(ex);
        }
    }

    @NonNull
    @Override
    public byte[] encrypt(
        @NonNull KeyStore appKeyStore,
        @NonNull String keyName,
        byte[] data
    ) {
        try {
            SecretKey key = (SecretKey) appKeyStore.getKey(keyName, null);
            Cipher cipher = Cipher.getInstance(CIPHER_TRANSFORMATION);
            cipher.init(Cipher.ENCRYPT_MODE, key);
            return cipher.doFinal(data);
        } catch (Exception ex) {
            if (BuildConfig.DEBUG) ex.printStackTrace();
            throw new SecureStorageDelegateError("Failed to encrypt data.");
        }
    }

    @NonNull
    @Override
    public BiometricPrompt.CryptoObject createCryptoObject(
        @NonNull KeyStore appKeyStore,
        @NonNull String keyName
    ) throws UserNotAuthenticatedException {
        try {
            SecretKey key = (SecretKey) appKeyStore.getKey(keyName, null);
            Cipher cipher = Cipher.getInstance(CIPHER_TRANSFORMATION);
            cipher.init(Cipher.DECRYPT_MODE, key);
            return new BiometricPrompt.CryptoObject(cipher);
        } catch (UserNotAuthenticatedException ex) {
            throw ex;
        } catch (Exception ex) {
            if (BuildConfig.DEBUG) ex.printStackTrace();
            throw new SecureStorageDelegateError(ex);
        }
    }

    @NonNull
    public byte[] decrypt(@NonNull BiometricPrompt.CryptoObject cryptoObject, byte[] data) {
        try {
            Cipher cipher = Objects.requireNonNull(cryptoObject.getCipher());
            return cipher.doFinal(data);
        } catch (BadPaddingException | IllegalBlockSizeException ex) {
            if (BuildConfig.DEBUG) ex.printStackTrace();
            throw new SecureStorageDelegateError("The data was invalid, so it couldn't be decrypted.");
        } catch (NullPointerException ex) {
            if (BuildConfig.DEBUG) ex.printStackTrace();
            throw new SecureStorageDelegateError("There was a problem whilst decrypting your data.");
        }
    }

    @Override
    public void performEncryptionTest(Context context, KeyStore appKeyStore) {
        EncryptionScheme.cipherTest(
            KeyProperties.KEY_ALGORITHM_AES,
            256,
            CIPHER_TRANSFORMATION,
            true
        );
    }

}
