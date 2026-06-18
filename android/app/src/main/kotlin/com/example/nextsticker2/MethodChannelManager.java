package com.example.nextsticker2;

import io.flutter.plugin.common.MethodChannel;
import java.util.ArrayList;
import java.util.List;

public class MethodChannelManager {
    private static final List<MethodChannel.MethodCallHandler> handlers = new ArrayList<>();
    private static MethodChannel methodChannel;

    public static void register(MethodChannel channel, MethodChannel.MethodCallHandler handler) {
        methodChannel = channel;
        // Avoid adding the same handler multiple times
        if (!handlers.contains(handler)) {
            handlers.add(handler);
        }
        channel.setMethodCallHandler(handler);
    }

    public static void unregister(MethodChannel.MethodCallHandler handler) {
        handlers.remove(handler);
        if (methodChannel != null) {
            if (handlers.isEmpty()) {
                methodChannel.setMethodCallHandler(null);
            } else {
                MethodChannel.MethodCallHandler lastHandler = handlers.get(handlers.size() - 1);
                methodChannel.setMethodCallHandler(lastHandler);
                methodChannel.invokeMethod("mapResumed", null);
            }
        }
    }
}
