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

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.security.InvalidAlgorithmParameterException;
import java.security.InvalidKeyException;
import java.security.KeyFactory;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.KeyStore;
import java.security.NoSuchAlgorithmException;
import java.security.PrivateKey;
import java.security.PublicKey;
import java.security.SecureRandom;
import java.security.cert.Certificate;
import java.security.spec.MGF1ParameterSpec;
import java.util.Arrays;
import java.util.Objects;

import javax.crypto.BadPaddingException;
import javax.crypto.Cipher;
import javax.crypto.IllegalBlockSizeException;
import javax.crypto.KeyGenerator;
import javax.crypto.Mac;
import javax.crypto.NoSuchPaddingException;
import javax.crypto.SecretKey;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.OAEPParameterSpec;
import javax.crypto.spec.PSource;
import javax.crypto.spec.SecretKeySpec;

import android.security.KeyStoreException;

public class HybridRSAEncryption implements EncryptionScheme {

    public static final String NAME = "HybridRSAEncryption";

    /** The cipher transformation for the outer RSA key. */
    private static final String CIPHER_TRANSFORMATION = "RSA/ECB/OAEPWithSHA-256AndMGF1Padding";

    /** The cipher transformation for the inner AES key. */
    private static final String CIPHER_INNER_TRANSFORMATION = "AES/CBC/PKCS7Padding";

    /** The HMAC algorithm to use. */
    private static final String HMAC_ALGORITHM = "HmacSHA256";

    public static void registerScheme() {
        EncryptionSchemeFactory.register(
            NAME, HybridRSAEncryption.class,
            // Should work on every device.
            HybridRSAEncryption::checkEligibility,
            EncryptionSchemeFactory.SchemeStrength.STRONG
        );
    }

    private static String checkEligibility(Context context, KeyStore appKeyStore) {
        // Attempt to initialize a KeyPair generator to check the algorithm.
        try {
            KeyPairGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_RSA,
                appKeyStore.getProvider()
            );
        } catch (NoSuchAlgorithmException ex) {
            // If we're here it means the device does not support RSA.
            return "Your device does not support any secure encryption algorithm.";
        }

        // Run an encryption test to check the algorithm.
        try {
            new HybridRSAEncryption().performEncryptionTest(context, appKeyStore);
        } catch (SecureStorageDelegateError ex) {
            return ex.getMessage();
        }

        // Otherwise, no issues.
        return null;
    }

    @Override
    public void generateKeyPair(MainActivity mainActivity, Context context, KeyStore appKeyStore, String name) {
        KeyGenParameterSpec.Builder keySpecBuilder = new KeyGenParameterSpec.Builder(
                name, KeyProperties.PURPOSE_DECRYPT
        )
            // Require user authentication for usage of the key.
            .setUserAuthenticationRequired(true)
            // Also handled by setUserAuthenticationParameters for Android R+.
            .setUserAuthenticationValidityDurationSeconds(-1)
            // Use OAEP padding for RSA.
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_RSA_OAEP)
            // Use 2048-bit keys.
            .setKeySize(2048)
            // Use SHA-256 key digest.
            .setDigests(KeyProperties.DIGEST_SHA256)
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
            KeyPairGenerator keyPairGenerator = KeyPairGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_RSA,
                "AndroidKeyStore"
            );

            // Generate the keypair using AndroidKeyStore and the above requirements.
            keyPairGenerator.initialize(keySpecBuilder.build());
            KeyPair keyPair = keyPairGenerator.generateKeyPair();

            // Load the key information to verify that the key meets the necessary
            // standards.
            KeyFactory factory = KeyFactory.getInstance(
                keyPair.getPrivate().getAlgorithm(), "AndroidKeyStore"
            );
            KeyInfo keyInfo = factory.getKeySpec(keyPair.getPrivate(), KeyInfo.class);

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
            // Generate a random AES key.
            KeyGenerator keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES);
            keyGenerator.init(256);
            SecretKey innerKey = keyGenerator.generateKey();

            // Initialize secure RNG.
            SecureRandom secureRandom = null;
            try {
                // If the SDK and device support it, use getInstanceStrong.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    secureRandom = SecureRandom.getInstanceStrong();
            } catch (Exception ignored) {}
            // Otherwise, ignore exceptions and fall back to the legacy SecureRandom constructor,
            // if it wasn't already initialized.
            if (secureRandom == null) secureRandom = new SecureRandom();

            // Generate a secure random initialization vector.
            byte[] iv = new byte[16];
            secureRandom.nextBytes(iv);
            IvParameterSpec ivParameterSpec = new IvParameterSpec(iv);

            // Encrypt the data with AES.
            Cipher innerCipher = Cipher.getInstance(CIPHER_INNER_TRANSFORMATION);
            innerCipher.init(Cipher.ENCRYPT_MODE, innerKey, ivParameterSpec);
            byte[] encryptedData = innerCipher.doFinal(data);

            // Now generate a SHA-256 message authentication code and use it to
            SecretKey innerHMACKey = keyGenerator.generateKey();
            secureRandom.nextBytes(innerHMACKey.getEncoded());
            Mac mac = Mac.getInstance(HMAC_ALGORITHM); // SHA-256 for compatibility.
            mac.init(new SecretKeySpec(innerHMACKey.getEncoded(), HMAC_ALGORITHM));
            mac.update(iv); // (equivalent to concatenation)
            byte[] messageAuthenticationCode = mac.doFinal(encryptedData);

            // Write the MAC key, MAC and encrypted message into a byte array stream.
            ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
            outputStream.write(iv); // 16 bytes
            outputStream.write(innerKey.getEncoded()); // 32 bytes
            outputStream.write(innerHMACKey.getEncoded()); // 32 bytes
            outputStream.write(messageAuthenticationCode); // 32 bytes
            outputStream.close();

            // Obtain the final ciphertext from the byte array stream.
            byte[] rawHeader = outputStream.toByteArray();

            // RSA-encrypt the header.
            PublicKey publicKey = appKeyStore.getCertificate(keyName).getPublicKey();
            Cipher cipher = Cipher.getInstance(CIPHER_TRANSFORMATION);
            cipher.init(Cipher.ENCRYPT_MODE, publicKey, new OAEPParameterSpec("SHA-256", "MGF1", MGF1ParameterSpec.SHA1, PSource.PSpecified.DEFAULT));
            byte[] header = cipher.doFinal(rawHeader);

            // Then concatenate the header and encrypted data.
            ByteArrayOutputStream payloadOutput = new ByteArrayOutputStream();
            payloadOutput.write(header); // Encrypted header size: 256 bytes
            payloadOutput.write(encryptedData);
            return payloadOutput.toByteArray();
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
            PrivateKey privateKey = (PrivateKey) appKeyStore.getKey(keyName, null);
            Cipher cipher = Cipher.getInstance(CIPHER_TRANSFORMATION);
            cipher.init(Cipher.DECRYPT_MODE, privateKey, new OAEPParameterSpec("SHA-256", "MGF1", MGF1ParameterSpec.SHA1, PSource.PSpecified.DEFAULT));
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
        Cipher cipher = Objects.requireNonNull(cryptoObject.getCipher());

        try {
            ByteArrayInputStream payloadInput = new ByteArrayInputStream(data);

            // Read the RSA-encrypted 'header' from the input stream.
            // Should be 256-bytes with padding.
            byte[] header = new byte[256];
            if (payloadInput.read(header) != 256) throw new SecureStorageDelegateError();

            // Load the AES-encrypted data.
            byte[] encryptedData = new byte[data.length - header.length];
            if (payloadInput.read(encryptedData) != data.length - header.length)
                throw new SecureStorageDelegateError();

            // RSA-decrypt the header.
            byte[] payload = cipher.doFinal(header);

            byte[] iv = new byte[16];
            byte[] innerKey = new byte[32];
            byte[] innerHMACKey = new byte[32];
            byte[] messageAuthenticationCode = new byte[32];

            // Split the header into its individual components.
            ByteArrayInputStream inputStream = new ByteArrayInputStream(payload);
            if (inputStream.read(iv) != iv.length) throw new SecureStorageDelegateError();
            if (inputStream.read(innerKey) != innerKey.length) throw new SecureStorageDelegateError();
            if (inputStream.read(innerHMACKey) != innerHMACKey.length) throw new SecureStorageDelegateError();
            if (inputStream.read(messageAuthenticationCode) != messageAuthenticationCode.length) throw new SecureStorageDelegateError();

            // Re-compute the MAC
            Mac mac = Mac.getInstance(HMAC_ALGORITHM);
            mac.init(new SecretKeySpec(innerHMACKey, HMAC_ALGORITHM));
            mac.update(iv);
            byte[] computedMessageAuthenticationCode = mac.doFinal(encryptedData);

            // Verify the MAC
            if (!Arrays.equals(computedMessageAuthenticationCode, messageAuthenticationCode)) {
                throw new SecureStorageDelegateError();
            }

            // Finally, AES-decrypt the wrapped data.
            IvParameterSpec ivParameterSpec = new IvParameterSpec(iv);
            Cipher innerCipher = Cipher.getInstance(CIPHER_INNER_TRANSFORMATION);
            innerCipher.init(
                Cipher.DECRYPT_MODE,
                new SecretKeySpec(innerKey, KeyProperties.KEY_ALGORITHM_AES),
                ivParameterSpec
            );
            return innerCipher.doFinal(encryptedData);
        } catch (BadPaddingException | IllegalBlockSizeException | InvalidKeyException | SecureStorageDelegateError ex) {
            if (BuildConfig.DEBUG) ex.printStackTrace();
            throw new SecureStorageDelegateError("The data was invalid, so it couldn't be decrypted.");
        } catch (NullPointerException | NoSuchAlgorithmException | InvalidAlgorithmParameterException | NoSuchPaddingException | IOException ex) {
            if (BuildConfig.DEBUG) ex.printStackTrace();
            throw new SecureStorageDelegateError("There was a problem whilst decrypting your data.");
        }
    }

    @Override
    public void performEncryptionTest(Context context, KeyStore appKeyStore) {
        // Test RSA
        EncryptionScheme.teeCipherTest(
            context,
            appKeyStore,
            KeyProperties.KEY_ALGORITHM_RSA,
            2048,
            KeyProperties.ENCRYPTION_PADDING_RSA_OAEP,
            KeyProperties.DIGEST_SHA256,
            CIPHER_TRANSFORMATION
        );

        // Test AES
        EncryptionScheme.cipherTest(
            KeyProperties.KEY_ALGORITHM_AES,
            256,
            CIPHER_INNER_TRANSFORMATION,
            true
        );

        // Test HMAC
        EncryptionScheme.macTest(HMAC_ALGORITHM);
    }

}
