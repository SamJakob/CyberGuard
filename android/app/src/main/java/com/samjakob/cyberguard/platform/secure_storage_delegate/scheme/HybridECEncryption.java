package com.samjakob.cyberguard.platform.secure_storage_delegate.scheme;

import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyInfo;
import android.security.keystore.KeyProperties;

import androidx.annotation.NonNull;
import androidx.biometric.BiometricPrompt;

import com.google.crypto.tink.Aead;
import com.google.crypto.tink.Registry;
import com.google.crypto.tink.aead.AeadConfig;
import com.google.crypto.tink.aead.AeadKeyTemplates;
import com.google.crypto.tink.hybrid.subtle.AeadOrDaead;
import com.google.crypto.tink.proto.AesGcmKey;
import com.google.crypto.tink.shaded.protobuf.ByteString;
import com.google.crypto.tink.subtle.EciesAeadHkdfDemHelper;
import com.google.crypto.tink.subtle.EciesAeadHkdfHybridEncrypt;
import com.google.crypto.tink.subtle.EllipticCurves;
import com.samjakob.cyberguard.BuildConfig;
import com.samjakob.cyberguard.MainActivity;
import com.samjakob.cyberguard.errors.SecureStorageDelegateError;

import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.Key;
import java.security.KeyFactory;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.KeyStore;
import java.security.NoSuchAlgorithmException;
import java.security.interfaces.ECKey;
import java.security.interfaces.ECPublicKey;
import java.security.spec.ECGenParameterSpec;

import javax.crypto.KeyAgreement;

import kotlin.NotImplementedError;

/**
 * THIS IS NOT CURRENTLY POSSIBLE TO IMPLEMENT ON ANDROID WITH USE OF A TRUSTED EXECUTION
 * ENVIRONMENT. AS SUCH, DO NOT USE THIS FOR NOW.
 * <p>
 * THE NECESSARY SUPPORT HAS BEEN REQUESTED HERE:
 * https://issuetracker.google.com/issues/281118580
 */
public class HybridECEncryption implements EncryptionScheme {

    public static final String NAME = "HybridECEncryption";

    /** NIST P-256 curve. */
    private static final String EC_CURVE = "secp256r1";

    public static void registerScheme() {
        EncryptionSchemeFactory.register(
            NAME, HybridECEncryption.class,
            // Test for eligibility (requires Android 12/S+).
            HybridECEncryption::checkEligibility,
            EncryptionSchemeFactory.SchemeStrength.PENDING_IMPLEMENTATION_AOSP
        );
    }

    private static String checkEligibility(Context context, KeyStore appKeyStore) {
        if (true) return "Necessary features not yet implemented in Android AOSP.";

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return "Your device must run Android 12 or greater to take advantage of the latest security features.";
        }

        // Attempt to initialize a KeyPair generator to check the algorithm.
        try {
            KeyPairGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_EC,
                appKeyStore.getProvider()
            );
        } catch (NoSuchAlgorithmException ex) {
            return "Your device does not support the latest encryption algorithms. You may experience reduced or poor performance.";
        }

        // Otherwise, no issues.
        return null;
    }

    @Override
    public void generateKeyPair(MainActivity mainActivity, Context context, KeyStore appKeyStore, String name) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return;

        KeyGenParameterSpec.Builder keySpecBuilder = new KeyGenParameterSpec.Builder(
            name, KeyProperties.PURPOSE_AGREE_KEY
        )
            // Use the specified curve for EC keys.
            .setAlgorithmParameterSpec(new ECGenParameterSpec(EC_CURVE))
            // Require user authentication for usage of the key.
            .setUserAuthenticationRequired(true)
            .setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
            // Allow new biometrics to be enrolled. See the comments in RSAEncryption.java.
            .setInvalidatedByBiometricEnrollment(false)
            // Require unlocked device.
            .setUnlockedDeviceRequired(true)
            ;

        // If a StrongBox implementation is available on the device, require StrongBox backing.
        if (context.getPackageManager().hasSystemFeature(PackageManager.FEATURE_STRONGBOX_KEYSTORE)) {
            keySpecBuilder = keySpecBuilder.setIsStrongBoxBacked(true);
        }

        try {
            KeyPairGenerator keyPairGenerator = KeyPairGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_EC,
                appKeyStore.getProvider()
            );

            // Use AndroidKeyStore with the requirements specified by the KeySpecBuilder to
            // generate an EC keypair.
            keyPairGenerator.initialize(keySpecBuilder.build());
            KeyPair keyPair = keyPairGenerator.generateKeyPair();

            // Load the key information from the key.
            KeyFactory factory = KeyFactory.getInstance(
                keyPair.getPrivate().getAlgorithm(), "AndroidKeyStore"
            );
            KeyInfo keyInfo = factory.getKeySpec(keyPair.getPrivate(), KeyInfo.class);

            // Verify the security standards of the key, preventing its use if it doesn't meet
            // security requirements.

            // See notes in RSAEncryption.java.
            // Verifies that the security level is at least that of a TEE. UNKNOWN_SECURE means the
            // exact nature of the secure implementation is not known, however it may be considered
            // to be at least as secure as a TEE.
            boolean isSecureKey = keyInfo.getSecurityLevel() >= KeyProperties.SECURITY_LEVEL_TRUSTED_ENVIRONMENT
                    || keyInfo.getSecurityLevel() == KeyProperties.SECURITY_LEVEL_UNKNOWN_SECURE;

            // Verify that the TEE or SE is responsible for verifying the user's authentication.
            // Ensures this cannot be bypassed at the OS-level.
            isSecureKey &= keyInfo.isUserAuthenticationRequirementEnforcedBySecureHardware();

            if (!isSecureKey) {
                throw new SecureStorageDelegateError("Failed to generate a secure key.");
            }
        } catch (Exception ex) {
            throw new SecureStorageDelegateError(ex);
        }
    }

    private static KeyStore appKeyStore;
    private static String keyName;

    @NonNull
    @Override
    public byte[] encrypt(
        @NonNull KeyStore appKeyStore,
        @NonNull String keyName,
        byte[] data
    ) {
        HybridECEncryption.appKeyStore = appKeyStore;
        HybridECEncryption.keyName = keyName;

        try {
            ECPublicKey publicKey = (ECPublicKey) appKeyStore.getCertificate(keyName).getPublicKey();
            return new EciesAeadHkdfHybridEncrypt(
                publicKey,
                new byte[]{},
                "HmacSha256",
                EllipticCurves.PointFormatType.UNCOMPRESSED,
                new CyberGuardAESGCM128EciesAeadHkdfDemHelper()
            ).encrypt(data, generateContextInfo(keyName));
        } catch (Exception ex) {
            if (BuildConfig.DEBUG) ex.printStackTrace();
            throw new SecureStorageDelegateError("Failed to encrypt data.");
        }
    }

    @NonNull
    @Override
    public byte[] decrypt(BiometricPrompt.CryptoObject cryptoObject, byte[] data) {
        try {
            ECKey privateKey = (ECKey) appKeyStore.getKey(keyName, null);

            ECPublicKey publicKey = (ECPublicKey) appKeyStore.getCertificate(keyName).getPublicKey();

            KeyAgreement agreement = KeyAgreement.getInstance("ECDH");
            agreement.init((Key) privateKey);
            agreement.doPhase(publicKey, true);

            byte[] secret = agreement.generateSecret();

            return null;
        } catch (Exception ex) {
            if (BuildConfig.DEBUG) ex.printStackTrace();
            throw new SecureStorageDelegateError("Failed to decrypt data.");
        }
    }

    @Override
    public void performEncryptionTest(Context context, KeyStore appKeyStore) {
        throw new NotImplementedError();
    }

    @NonNull
    @Override
    public BiometricPrompt.CryptoObject createCryptoObject(
        @NonNull KeyStore appKeyStore,
        @NonNull String keyName
    ) {
        try {
//            return new BiometricPrompt.CryptoObject();

//            int headerSize = EllipticCurves.encodingSizeInBytes(
//                privateKey.getParams().getCurve(),
//                EllipticCurves.PointFormatType.UNCOMPRESSED
//            );
//
//            System.out.println(privateKey.getParams());
//
            return null;
        } catch (Exception ex) {
            if (BuildConfig.DEBUG) ex.printStackTrace();
            throw new SecureStorageDelegateError("Failed to decrypt data.");
        }
    }

    /// ENCRYPTION PRIMITIVES

    private static byte[] generateContextInfo(String keyName) {
        return String.format("CyberGuard_SJAB$%s", keyName).getBytes(StandardCharsets.UTF_8);
    }

    private static class CyberGuardAESGCM128EciesAeadHkdfDemHelper implements EciesAeadHkdfDemHelper {
        private final AesGcmKey key;

        CyberGuardAESGCM128EciesAeadHkdfDemHelper() throws GeneralSecurityException {
            this.key = (AesGcmKey) Registry.newKey(AeadKeyTemplates.AES128_GCM);
        }

        @Override
        public int getSymmetricKeySizeInBytes() {
            return 16;
        }

        @Override
        public AeadOrDaead getAeadOrDaead(byte[] symmetricKeyValue) throws GeneralSecurityException {
            if (symmetricKeyValue.length != 16) throw new GeneralSecurityException("Invalid or corrupted encryption key.");

            AesGcmKey aeadKey = AesGcmKey.newBuilder()
                    .mergeFrom(key)
                    .setKeyValue(ByteString.copyFrom(symmetricKeyValue, 0, 16))
                    .build();

            return new AeadOrDaead(Registry.getPrimitive(AeadConfig.AES_GCM_TYPE_URL, aeadKey, Aead.class));
        }
    }

}
