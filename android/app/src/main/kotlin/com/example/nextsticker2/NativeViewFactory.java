package com.example.nextsticker2;

import android.app.Activity;
import android.content.Context;
import androidx.annotation.Nullable;
import androidx.annotation.NonNull;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;
import java.util.Map;

class NativeViewFactory extends PlatformViewFactory {
    private final BinaryMessenger messenger;
    //@NonNull private final View containerView;
    private final Activity activity;
    NativeViewFactory(
            BinaryMessenger messenger,
            //@NonNull View containerView
            Activity activity
    ) {
        super(StandardMessageCodec.INSTANCE);
        this.messenger = messenger;
        this.activity = activity;

        //this.containerView = containerView;
    }
    @Override
    public PlatformView create(Context context, int id, Object args) {
        final Map<String, Object> creationParams = (Map<String, Object>) args;
        return new NativeView(context, messenger, id, creationParams, activity);
    }
}