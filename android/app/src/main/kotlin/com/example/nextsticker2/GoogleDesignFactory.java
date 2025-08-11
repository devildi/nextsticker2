package com.example.nextsticker2;

import android.app.Activity;
import android.content.Context;

import org.jetbrains.annotations.Nullable;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;
import java.util.Map;

public class GoogleDesignFactory extends PlatformViewFactory{
    private final BinaryMessenger messenger;
    private final Activity activity;
    GoogleDesignFactory(
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
    public PlatformView create( Context context, int id, @Nullable Object args) {
        final Map<String, Object> creationParams = (Map<String, Object>) args;
        return new GoogleDesign(context, messenger, id, creationParams, activity);
    }
}
