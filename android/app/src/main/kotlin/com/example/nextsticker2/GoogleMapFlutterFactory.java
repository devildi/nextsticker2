package com.example.nextsticker2;

import android.app.Activity;
import android.content.Context;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.Map;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;

class GoogleMapFlutterFactory extends PlatformViewFactory {
    @NonNull private final BinaryMessenger messenger;
    //@NonNull private final View containerView;
    @NonNull private final Activity activity;

    GoogleMapFlutterFactory(@NonNull BinaryMessenger messenger,  @NonNull Activity activity) {
        super(StandardMessageCodec.INSTANCE);
        this.messenger = messenger;
        this.activity = activity;
        //this.containerView = containerView;
    }

    @NonNull
    @Override
    public PlatformView create(@NonNull Context context, int id, @Nullable Object args) {
        final Map<String, Object> creationParams = (Map<String, Object>) args;
        return new GoogleMapFlutter(context, messenger, id, creationParams, activity);
    }
}
