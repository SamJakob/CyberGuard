package com.samjakob.cyberguard;

import android.os.Bundle;
import android.view.WindowManager;
import androidx.annotation.Nullable;
import io.flutter.embedding.android.FlutterActivity;

public class MainActivity extends FlutterActivity {

    @Override
    protected void onCreate(@Nullable @org.jetbrains.annotations.Nullable Bundle savedInstanceState) {
        // Prevent screenshotting of the application, etc.,
        getWindow().setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE);

        super.onCreate(savedInstanceState);
    }
}
