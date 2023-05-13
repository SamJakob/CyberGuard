package com.samjakob.cyberguard.utils;

import android.os.Build;

public class PlatformHelpers {

    /**
     * Employs a heuristic approach to determine if the Android
     * device is a simulator, or real device.
     */
    public static boolean checkIfSimulator() {
        boolean isEmulator;

        // Check the radio version (if it's not set, or 1.0.0.0,
        // the device must be an emulator).
        String deviceRadioVersion = Build.getRadioVersion();
        isEmulator = (deviceRadioVersion == null || deviceRadioVersion.isEmpty() || deviceRadioVersion.equals("1.0.0.0"));

        // The approach used by Google's Firebase is to check for certain
        // HARDWARE or PRODUCT attributes.
        isEmulator |= (Build.PRODUCT.contains("sdk") ||
                Build.HARDWARE.contains("goldfish") ||
                Build.HARDWARE.contains("ranchu"));

        // Finally, check if the PRODUCT is explicitly set to 'emulator'
        // or 'simulator' (per Flutter's historic approach).
        isEmulator |= (Build.PRODUCT.contains("emulator") ||
                Build.PRODUCT.contains("simulator"));

        return isEmulator;
    }

}
