package com.samjakob.cyberguard;

import android.os.Bundle;
import android.view.WindowManager;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.samjakob.cyberguard.platform.CGASecureStorage;
import com.samjakob.cyberguard.platform.CGAUserPresence;

import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;

public class MainActivity extends FlutterFragmentActivity {

    @Override
    protected void onCreate(@Nullable @org.jetbrains.annotations.Nullable Bundle savedInstanceState) {
        // Prevent screenshotting of the application, etc.,
//        getWindow().setFlags(
//            WindowManager.LayoutParams.FLAG_SECURE,
//            WindowManager.LayoutParams.FLAG_SECURE
//        );

        super.onCreate(savedInstanceState);
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        CGASecureStorage.createSecureStorageChannel(flutterEngine, getApplicationContext(), this);
        CGAUserPresence.createSecureStorageChannel(flutterEngine, getApplicationContext(), this);
    }

}
