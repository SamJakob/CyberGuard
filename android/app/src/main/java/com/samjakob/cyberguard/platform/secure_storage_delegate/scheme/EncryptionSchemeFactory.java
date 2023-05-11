package com.samjakob.cyberguard.platform.secure_storage_delegate.scheme;

import android.content.Context;
import android.content.SharedPreferences;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.samjakob.cyberguard.BuildConfig;
import com.samjakob.cyberguard.errors.SecureStorageDelegateError;

import java.security.KeyStore;
import java.util.HashMap;
import java.util.Map;

public class EncryptionSchemeFactory {
    private final Map<String, EncryptionSchemeOption> encryptionSchemes;
    private static EncryptionSchemeFactory instance;

    public EncryptionSchemeFactory() {
        encryptionSchemes = new HashMap<>();
    }

    private static EncryptionSchemeFactory getFactory() {
        if (instance == null) return (instance = new EncryptionSchemeFactory());
        else return instance;
    }

    public static EncryptionSchemeOption getByName(String name) {
        return getFactory().encryptionSchemes.get(name);
    }

    public static String nameFor(EncryptionScheme scheme) {
        // Attempt to look up the EncryptionScheme in encryptionSchemes to get the
        // registered name.
        // This should be more resistant to obfuscation.
        for (Map.Entry<String, EncryptionSchemeOption> schemeOptionEntry : getFactory().encryptionSchemes.entrySet()) {
            if (schemeOptionEntry.getValue().scheme.equals(scheme.getClass())) {
                return schemeOptionEntry.getKey();
            }
        }

        // Otherwise, simply return the class name.
        return scheme.getClass().getSimpleName();
    }

    public static void register(
        String name,
        Class<? extends EncryptionScheme> scheme,
        SchemeEligibilityChecker eligibilityChecker,
        SchemeStrength strength
    ) {
        getFactory().encryptionSchemes.put(
            name,
            new EncryptionSchemeOption(
                scheme,
                eligibilityChecker,
                strength
            )
        );
    }

    /**
     * Returns the first eligible scheme with the highest strength (or,
     * if minimumStrength is specified, the first eligible scheme of that
     * strength or greater).
     * @param keyStore The key store that will perform the encryption
     *                 scheme. This is used to check if certain algorithms
     *                 will work on the platform.
     * @param minimumStrength The minimum strength to obtain. Null means
     *                        any strength.
     * @return An {@link EncryptionSchemeChoice} with the most secure scheme
     * possible on the current device.
     */
    @NonNull
    private static EncryptionSchemeChoice searchForEligibleScheme(@NonNull Context context, @NonNull KeyStore keyStore, @Nullable SchemeStrength minimumStrength) {
        String message = null;
        EncryptionSchemeOption selectedOption = null;
        EncryptionSchemeOption previouslyConsideredOption = null;

        for (EncryptionSchemeOption option : getFactory().encryptionSchemes.values()) {
            // If selectedOption has a greater (or equal) strength than the current scheme,
            // skip the current scheme.
            if (selectedOption != null && selectedOption.strength.value >= option.strength.value)
                continue;

            // If there is a minimum strength specified, ensure that this scheme
            // meets the requirement.
            if (minimumStrength != null && option.strength.value < minimumStrength.value) continue;

            // Check the current option for eligibility.
            // If it fails, record the reason, otherwise, select the scheme.
            String eligibilityIssue = option.eligibilityChecker.checkEligibility(context, keyStore);
            if (eligibilityIssue != null) {
                // If the previously considered option is less strong (or as strong as
                // the current one), keep the eligibility message from that one.
                if (previouslyConsideredOption != null &&
                        previouslyConsideredOption.strength.value <= option.strength.value) {
                    // Register the previously considered option, so we can get the eligibility
                    // message from the lower strength option.
                    previouslyConsideredOption = option;
                    continue;
                }

                previouslyConsideredOption = option;
                message = eligibilityIssue;
                continue;
            }

            previouslyConsideredOption = option;
            selectedOption = option;

            // If there's no eligibility issue (which will be the case if we're here), and the
            // scheme is STRONG, we can simply choose this scheme without evaluating others.
            if (option.strength.value >= SchemeStrength.STRONG.value) {
                break;
            }
        }

        // Attempt to instantiate the scheme, if one was selected.
        if (selectedOption != null) {
            // Clear the warning message if the currently selected scheme is STRONG.
            // Otherwise, it will serve as a reason why we downgraded from a STRONG scheme.
            if (selectedOption.strength.value >= SchemeStrength.STRONG.value) message = null;

            try {
                return new EncryptionSchemeChoice(message, selectedOption.scheme.newInstance());
            } catch (IllegalAccessException | InstantiationException ex) {
                throw new SecureStorageDelegateError("Failed to instantiate encryption scheme.");
            }
        }

        return new EncryptionSchemeChoice(
                message != null
                        ? message
                        : "Your device does not support the secure encryption schemes used in the application.",
                null
        );
    }

    /** @see #getEligibleScheme(Context, KeyStore, SchemeStrength) */
    public static EncryptionSchemeChoice getEligibleScheme(@NonNull Context context, @NonNull KeyStore keyStore) {
        return getEligibleScheme(context, keyStore, null);
    }

    /**
     * Searches for an eligible scheme for the current platform, then once it is selected, 'locks
     * in' that choice by storing the factory name of the selected scheme in private preferences.
     * @param context The application context.
     * @param keyStore The keystore.
     * @param minimumStrength The minimum strength of the scheme to be used.
     * @return The scheme to be used, otherwise null if none could be found.
     */
    public static EncryptionSchemeChoice getEligibleScheme(@NonNull Context context, @NonNull KeyStore keyStore, @Nullable SchemeStrength minimumStrength) {
        // Access the shared preferences for platform settings.
        SharedPreferences platformPrefs = context.getSharedPreferences("__CGA_PLATFORM", Context.MODE_PRIVATE);

        // If there is a scheme in the platform settings section, attempt to load it.
        if (platformPrefs.contains("scheme")) {
            try {
                String schemeName = platformPrefs.getString("scheme", null);
                if (schemeName == null) throw new SecureStorageDelegateError("Failed to find previously used encryption scheme.");

                final EncryptionSchemeOption schemeOption = getByName(schemeName);
                final String message = platformPrefs.getString("scheme_message", null);

                return new EncryptionSchemeChoice(message, schemeOption.scheme.newInstance());
            } catch (Exception ex) {
                if (BuildConfig.DEBUG) ex.printStackTrace();
                throw new SecureStorageDelegateError("Failed to prepare encryption scheme.");
            }
        }

        // Otherwise, search for an eligible scheme and, if there is one, store it, otherwise
        // return the choice object directly (which contains the error message).
        final EncryptionSchemeChoice schemeChoice = searchForEligibleScheme(context, keyStore, minimumStrength);
        if (schemeChoice.scheme == null) return schemeChoice;

        SharedPreferences.Editor platformPrefsEditor = platformPrefs.edit();
        platformPrefsEditor.putString("scheme", EncryptionSchemeFactory.nameFor(schemeChoice.scheme));
        platformPrefsEditor.putString("scheme_message", schemeChoice.message);
        platformPrefsEditor.apply();
        return schemeChoice;
    }

    public static class EncryptionSchemeChoice {
        public final String message;
        public final EncryptionScheme scheme;

        public EncryptionSchemeChoice(String message, EncryptionScheme scheme) {
            this.message = message;
            this.scheme = scheme;
        }
    }

    private static class EncryptionSchemeOption {
        public final SchemeEligibilityChecker eligibilityChecker;
        public final Class<? extends EncryptionScheme> scheme;
        public final SchemeStrength strength;

        public EncryptionSchemeOption(
            Class<? extends EncryptionScheme> scheme,
            SchemeEligibilityChecker eligibilityChecker,
            SchemeStrength strength
        ) {
            this.eligibilityChecker = eligibilityChecker;
            this.scheme = scheme;
            this.strength = strength;
        }
    }

    public interface SchemeEligibilityChecker {
        /**
         * Returns a string indicating the eligibility issue the device
         * has with the current device. Otherwise, returns null to indicate
         * no eligibility issues.
         *
         * @param context The Android app context. Used to test for features, etc.,
         * @param appKeyStore The keystore, used to perform additional checks (e.g., algorithms).
         * @return String issue, or null.
         */
        @Nullable
        String checkEligibility(Context context, KeyStore appKeyStore);
    }

    /**
     * Indicates the strength (how optimal) the scheme is. Both from performance perspective, as
     * well as security (encryption) strength of the scheme.
     * Higher (stronger) is better.
     * <p>
     * This is essentially a priority mechanism.
     */
    public enum SchemeStrength {
        /**
         * This scheme requires that functionality be introduced to the Android Open Source Project
         * (AOSP).
         */
        PENDING_IMPLEMENTATION_AOSP(-99),

        /** This scheme has yet to be implemented in the app. */
        PENDING_IMPLEMENTATION_APP(-1),

        /**
         * This scheme is a fallback, it should not be used unless other schemes simply won't
         * function on the device.
         */
        FALLBACK(0),

        /**
         * This scheme is relatively weaker than {@link #STRONG}, but it is considered adequate
         * for use.
         * Ideally, a replacement STRONG scheme for the device would be introduced (or some other
         * alternative).
         */
        WEAK(1),

        /** This is an up-to-date, strong and suitable encryption scheme. */
        STRONG(2);

        public final int value;
        SchemeStrength(int value) {
            this.value = value;
        }
    }

}
