package com.example.nextsticker2;

import android.app.Activity;
import android.content.Context;
import android.util.Log;

import com.amap.api.services.core.AMapException;
import com.amap.api.services.poisearch.PoiSearch;
import com.amap.api.services.poisearch.PoiSearch.OnPoiSearchListener;
import com.amap.api.services.poisearch.PoiSearch.Query;
import com.amap.api.services.poisearch.PoiResult;
import com.amap.api.services.core.PoiItem;

import com.amap.api.services.core.AMapException;
import com.amap.api.services.poisearch.PoiSearch;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import javax.xml.transform.Result;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;
import android.Manifest;
import android.content.pm.PackageManager;

public class NativeViewPlgin implements FlutterPlugin, ActivityAware , OnPoiSearchListener, PluginRegistry.RequestPermissionsResultListener {
    private Activity activity;
    FlutterPluginBinding binding1;

    private MethodChannel methodChannel;

    PoiSearch.Query query;
    PoiSearch poiSearch;
    private Context applicationContext;
    private MethodChannel.Result pendingResult;


    @Override
    public void onAttachedToEngine( FlutterPluginBinding binding) {
        Log.e("NativeViewPlgin", "插件已注册");
        applicationContext = binding.getApplicationContext();
        binding1 = binding;
        methodChannel = new MethodChannel(binding.getBinaryMessenger(), "gaode_api_channel");
        methodChannel.setMethodCallHandler((call, result) -> {
            Log.e("amap", "InjectData");
            switch (call.method) {
                case "getLocation":
                    this.pendingResult = result;

                    String text = (String) call.arguments;
                    query = new PoiSearch.Query(text, "", "");
                    query.setPageSize(5);
                    try {
                        poiSearch = new PoiSearch(applicationContext, query);
                    } catch (AMapException e) {
                        e.printStackTrace();
                    }
                    poiSearch.setOnPoiSearchListener(this);
                    poiSearch.searchPOIAsyn();

                    break;
                default:
                    result.notImplemented();
            }
        });
    }

    @Override
    public void onDetachedFromEngine( FlutterPluginBinding binding) {
        Log.e("getActivity", "111getActivity");
    }

    private ActivityPluginBinding activityBinding;

    @Override
    public void onAttachedToActivity( ActivityPluginBinding binding) {
        Log.e("getActivity", "onAttachedToActivity");
        activity = binding.getActivity();
        activityBinding = binding;
        activityBinding.addRequestPermissionsResultListener(this);
        BinaryMessenger messenger = binding1.getBinaryMessenger();
        binding1.getPlatformViewRegistry()
                .registerViewFactory(
                        "gaode_native_IOS", new NativeViewFactory(messenger, activity));

        binding1.getPlatformViewRegistry()
                .registerViewFactory(
                        "google_native_IOS", new GoogleMapFlutterFactory(messenger, activity));

        binding1.getPlatformViewRegistry()
                .registerViewFactory(
                        "gaodeDesign", new GaodeDesignFactory(messenger, activity));

        binding1.getPlatformViewRegistry()
                .registerViewFactory(
                        "googleDesign", new GoogleDesignFactory(messenger, activity));
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        Log.e("getActivity", "111getActivity");
        if (activityBinding != null) {
            activityBinding.removeRequestPermissionsResultListener(this);
            activityBinding = null;
        }
    }

    @Override
    public void onReattachedToActivityForConfigChanges( ActivityPluginBinding binding) {
        Log.e("getActivity", "222getActivity");
        activity = binding.getActivity();
        activityBinding = binding;
        activityBinding.addRequestPermissionsResultListener(this);
    }

    @Override
    public void onDetachedFromActivity() {
        Log.e("getActivity", "333getActivity");
        if (activityBinding != null) {
            activityBinding.removeRequestPermissionsResultListener(this);
            activityBinding = null;
        }
    }

    @Override
    public boolean onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        if (requestCode == 1) {
            boolean granted = false;
            for (int i = 0; i < permissions.length; i++) {
                if (Manifest.permission.ACCESS_COARSE_LOCATION.equals(permissions[i]) 
                    || Manifest.permission.ACCESS_FINE_LOCATION.equals(permissions[i])) {
                    if (grantResults[i] == PackageManager.PERMISSION_GRANTED) {
                        granted = true;
                    }
                }
            }
            if (granted && binding1 != null) {
                MethodChannel nativeChannel = new MethodChannel(binding1.getBinaryMessenger(), "gaode_native_channel");
                nativeChannel.invokeMethod("permissionGranted", null);
            }
        }
        return false;
    }

    @Override
    public void onPoiSearched(PoiResult poiResult, int rCode) {
        if (pendingResult == null) return;

        if (rCode == 1000 && poiResult != null && poiResult.getPois() != null && !poiResult.getPois().isEmpty()) {
            // 只获取第一个POI元素
            PoiItem firstItem = poiResult.getPois().get(0);

            Map<String, Object> poiMap = new HashMap<>();
            poiMap.put("title", firstItem.getTitle());
            poiMap.put("snippet", firstItem.getSnippet());
            poiMap.put("latLng", new HashMap<String, Double>() {{
                put("latitude", firstItem.getLatLonPoint().getLatitude());
                put("longitude", firstItem.getLatLonPoint().getLongitude());
            }});
            poiMap.put("city", firstItem.getCityName());
            poiMap.put("address", firstItem.getSnippet());

            pendingResult.success(poiMap); // 只返回单个元素
        } else {
            pendingResult.error("SEARCH_FAILED", "未找到结果或搜索失败，错误码: " + rCode, null);
        }

        pendingResult = null;
    }

    @Override
    public void onPoiItemSearched(PoiItem poiItem, int i) {

    }
}
