package com.samjakob.cyberguard.platform;

import static com.samjakob.cyberguard.utils.PlatformHelpers.checkIfSimulator;

import android.content.Context;
import android.os.Build;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.biometric.BiometricManager;
import androidx.biometric.BiometricPrompt;
import androidx.core.content.ContextCompat;

import com.samjakob.cyberguard.MainActivity;
import com.samjakob.cyberguard.errors.SecureStorageDelegateError;

import org.jetbrains.annotations.NotNull;

import java.util.HashMap;
import java.util.concurrent.Executor;
import java.util.concurrent.atomic.AtomicReference;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class CGAUserPresence {

    /** The Flutter Platform Channel name for the User Presence implementation. */
    private static final String USER_PRESENCE_CHANNEL = "com.samjakob.cyberguard/user_presence";

    /**
     * The current version of the platform channel specification implemented by this
     * implementation.
     */
    private static final int USER_PRESENCE_IMPL_VERSION = 1;

    private final Executor mainExecutor;
    private final MainActivity mainActivity;

    /**
     * An atomic reference to the current verification biometric prompt. For security reasons,
     * only one is allowed at a time so it is clear to both the app and user what they are
     * authenticating with.
     */
    AtomicReference<BiometricPrompt> verificationBiometricPrompt = new AtomicReference<>();

    public CGAUserPresence(Executor mainExecutor, MainActivity mainActivity) {
        this.mainExecutor = mainExecutor;
        this.mainActivity = mainActivity;
    }

    public void handle(MethodCall call, MethodChannel.Result result) {
        if ("ping".equals(call.method)) {
            // Test for functionality
            String functionalityError = checkFunctionality();

            // If there is a problem with functionality, return an error.
            // Otherwise, allow the ping to proceed.
            if (functionalityError != null) {
                result.error("USER_PRESENCE_FAILURE", functionalityError, null);
                return;
            } else {
                HashMap<String, Object> response = new HashMap<>();

                // Useful for simple tests to ensure the platform channel is
                // available.
                response.put("ping", "pong");
                response.put("version", USER_PRESENCE_IMPL_VERSION);

                response.put("is_simulator", checkIfSimulator());

                result.success(response);
            }
        }

        // Handle other method calls.
        try {
            switch (call.method) {
                case "cancelVerifyUserPresence": {
                    cancelVerifyUserPresence();
                    result.success(null);
                    break;
                }

                case "verifyUserPresence": {
                    verifyUserPresence(result);
                    break;
                }
            }
        } catch (Exception ex) {
            result.error(
            "USER_PRESENCE_FAILURE",
            "There was a problem verifying your identity.",
            null
            );
        }
    }

    @Nullable
    public String checkFunctionality() {
        int biometricStatus = BiometricManager.from(mainActivity.getApplicationContext()).canAuthenticate(
                BiometricManager.Authenticators.BIOMETRIC_STRONG
        );

        if (biometricStatus == BiometricManager.BIOMETRIC_SUCCESS) {
            return null;
        } else {
            switch (biometricStatus) {
                case BiometricManager.BIOMETRIC_STATUS_UNKNOWN:
                    return "Your device didn't report any biometric capabilities.";
                case BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED:
                    return "You don't have any biometrics enrolled on your device.";
                case BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE:
                case BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE:
                case BiometricManager.BIOMETRIC_ERROR_UNSUPPORTED:
                    return "Your device doesn't have any supported biometric hardware available.";
                case BiometricManager.BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED:
                    return "You need to apply a security update to use biometrics on your device.";
                default:
                    return "Your device is missing biometric functionality.";
            }
        }
    }

    public void cancelVerifyUserPresence() {
        // If there is an existing biometric prompt, cancel it.
        if (verificationBiometricPrompt.get() != null) {
            verificationBiometricPrompt.get().cancelAuthentication();
        }
    }

    public void verifyUserPresence(MethodChannel.Result flutterResult) {
        final String NEGATIVE_BUTTON_TEXT = "Cancel";

        // If there is an existing biometric prompt, cancel it.
        if (verificationBiometricPrompt.get() != null) {
            verificationBiometricPrompt.get().cancelAuthentication();
        }

        BiometricPrompt.PromptInfo promptInfo = new BiometricPrompt.PromptInfo.Builder()
                .setTitle("Verify Your Identity")
                .setSubtitle("This is an extra step to make sure that it's you accessing your data.")
                .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                .setNegativeButtonText(NEGATIVE_BUTTON_TEXT)
                .build();
        BiometricPrompt.AuthenticationCallback authCallback = new BiometricPrompt.AuthenticationCallback() {
            private int remainingAttempts = 3;

            @Override
            public void onAuthenticationError(int errorCode, @NonNull CharSequence errString) {
                if (errString.equals(NEGATIVE_BUTTON_TEXT)) {
                    errString = "Authentication was cancelled.";
                }

                // Simply cancel authentication on error.
                if (verificationBiometricPrompt.get() != null) verificationBiometricPrompt.get().cancelAuthentication();
                verificationBiometricPrompt.set(null);
                flutterResult.error(
                        "USER_PRESENCE_FAILURE",
                        "There was a problem checking your identity.",
                        errString
                );
            }

            @Override
            public void onAuthenticationSucceeded(@NonNull BiometricPrompt.AuthenticationResult result) {
                try {
                    if (result.getAuthenticationType() != BiometricPrompt.AUTHENTICATION_RESULT_TYPE_BIOMETRIC) {
                        throw new SecureStorageDelegateError("Invalid biometric type used.");
                    }

                    verificationBiometricPrompt.set(null);
                    flutterResult.success(true);
                } catch (Exception ex) {
                    flutterResult.error(
                            "USER_PRESENCE_FAILURE",
                            "Failed to verify user presence.",
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
                    if (verificationBiometricPrompt.get() != null)
                        verificationBiometricPrompt.get().cancelAuthentication();
                    verificationBiometricPrompt.set(null);
                }
            }
        };

        verificationBiometricPrompt.set(new BiometricPrompt(mainActivity, mainExecutor, authCallback));
        verificationBiometricPrompt.get().authenticate(promptInfo);
    }

    /**
     * Registers a CGAUserPresence instance to handle platform requests from Flutter.
     *
     * @param flutterEngine The engine to handle platform channel messages from.
     * @param context       The Application or MainActivity context.
     * @param mainActivity  The MainActivity.
     */
    public static void createSecureStorageChannel(@NonNull FlutterEngine flutterEngine, @NotNull Context context, MainActivity mainActivity) {
        Executor mainExecutor;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            mainExecutor = context.getMainExecutor();
        } else {
            mainExecutor = ContextCompat.getMainExecutor(context);
        }

        CGAUserPresence userPresence = new CGAUserPresence(mainExecutor, mainActivity);
        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                USER_PRESENCE_CHANNEL
        ).setMethodCallHandler(userPresence::handle);
    }

}
