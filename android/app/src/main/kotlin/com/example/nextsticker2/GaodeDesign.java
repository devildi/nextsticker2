package com.example.nextsticker2;

import android.app.Activity;
import android.content.Context;
import android.graphics.Bitmap;
import android.os.Bundle;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.ImageView;
import android.widget.TextView;

import androidx.appcompat.app.AppCompatActivity;

import com.amap.api.maps.AMap;
import com.amap.api.maps.AMapOptions;
import com.amap.api.maps.CameraUpdateFactory;
import com.amap.api.maps.MapView;
import com.amap.api.maps.MapsInitializer;
import com.amap.api.maps.UiSettings;
import com.amap.api.maps.model.BitmapDescriptorFactory;
import com.amap.api.maps.model.CameraPosition;
import com.amap.api.maps.model.LatLng;
import com.amap.api.maps.model.Marker;
import com.amap.api.maps.model.MarkerOptions;
import com.amap.api.services.core.AMapException;
import com.amap.api.services.core.PoiItem;
import com.amap.api.services.core.ServiceSettings;

import org.jetbrains.annotations.Nullable;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.platform.PlatformView;

import java.util.ArrayList;
import java.util.Map;

import com.amap.api.services.poisearch.PoiResult;
import com.amap.api.services.poisearch.PoiSearch;
import com.android.volley.RequestQueue;
import com.android.volley.toolbox.ImageLoader;
import com.android.volley.toolbox.Volley;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;

class GaodeDesign  extends AppCompatActivity implements PlatformView, MethodChannel.MethodCallHandler, AMap.OnMarkerClickListener, AMap.InfoWindowAdapter, PoiSearch.OnPoiSearchListener {
    Context context1;
    Activity activity1;
    private MapView mapView;
    private AMap aMap;
    private final UiSettings mUiSettings;
    MethodChannel methodChannel;
    private final View nativeView;
    String imageUrl;
    ImageView imageView;
    ImageLoader imageLoader;
    RequestQueue requestQueue;
    PoiSearch.Query query;
    PoiSearch poiSearch;
    private MethodChannel.Result pendingResult;
    private Marker marker;

    GaodeDesign(Context context, BinaryMessenger messenger, int id, Map<String, Object> creationParams, Activity activity) {
        MapsInitializer.updatePrivacyShow(context,true,true);
        MapsInitializer.updatePrivacyAgree(context,true);
        ServiceSettings.updatePrivacyShow(context,true,true);
        ServiceSettings.updatePrivacyAgree(context,true);
        nativeView = LayoutInflater.from(context).inflate(R.layout.infowindow, null);
        methodChannel = new MethodChannel(messenger, "gaode_native_channel");
        methodChannel.setMethodCallHandler(this);
        context1 = context;
        activity1 = activity;
        String pointString = creationParams.get("pointsString").toString();

        if(mapView != null){
            mapView.onResume();
        }
        Log.e("map","设计地图初始化");
        AMapOptions mapOptions = new AMapOptions();
        mapView = new MapView(context);
        mapView.onCreate(new Bundle());
        if (aMap == null) {
            aMap = mapView.getMap();
        }
        //地图控件
        mUiSettings = aMap.getUiSettings();
        mUiSettings.setZoomControlsEnabled(false);
        mUiSettings.setRotateGesturesEnabled(false);
        mUiSettings.setTiltGesturesEnabled(false);
        //显示点标记
        initData(pointString);
        aMap.addOnMarkerClickListener(this);
        //网络请求
        requestQueue = Volley.newRequestQueue(context1);
        imageLoader = new ImageLoader(requestQueue, new ImageLoader.ImageCache() {
            @Override
            public Bitmap getBitmap(String url) {
                return null;
            }

            @Override
            public void putBitmap(String url, Bitmap bitmap) {
                // 可以实现自定义的图片缓存逻辑
            }
        });
        AMap.OnInfoWindowClickListener listener = arg0 -> {
            ObjectMapper objectMapper = new ObjectMapper();
            Log.e("map",marker.getTitle());
            ObjectNode jsonNode = objectMapper.createObjectNode();
            jsonNode.put("nameOfScence", marker.getTitle());
            jsonNode.put("longitude", marker.getPosition().longitude);
            jsonNode.put("latitude", marker.getPosition().latitude);
            try {
                methodChannel.invokeMethod("openModal",objectMapper.writeValueAsString(jsonNode));
            } catch (JsonProcessingException e) {
                e.printStackTrace();
            }
            marker.hideInfoWindow();
        };
        aMap.setOnInfoWindowClickListener(listener);
        aMap.setInfoWindowAdapter(this);
    }

    @Nullable
    @Override
    public View getView() {
        mapView.onResume();
        return mapView;
    }


    @Override
    public void dispose() {
        mapView.onPause();
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        if ("startLoaction".equals(call.method)) {
            String text = (String) call.arguments;
        }else if ("InjectOnePoint".equals(call.method)) {
            Log.e("flutterMethod", call.method);
            this.pendingResult = result;
            String pointString = (String) call.arguments;
            initData(pointString);
        }else if ("findPOI".equals(call.method)) {
            String text = (String) call.arguments;
            query = new PoiSearch.Query(text, "", "");
            query.setPageSize(5);
            try {
                poiSearch = new PoiSearch(context1, query);
            } catch (AMapException e) {
                e.printStackTrace();
            }
            poiSearch.setOnPoiSearchListener(this);
            poiSearch.searchPOIAsyn();
            result.success(text);
        } else if ("clearPOI".equals(call.method)){
            Log.e("map","清屏");
            aMap.clear();
        }
    }

    private void initData(String pointString){
        Log.e("map","开始渲染一个点坐标");
        aMap.clear();
        //Log.e("map",pointString);
        if(pointString != ""){
            String jsonStr = pointString.replace("{", "{\"");
            jsonStr = jsonStr.replace(": ", "\":\"");
            jsonStr = jsonStr.replace(", ", "\",\"");
            jsonStr = jsonStr.replace("}", "\"}");
            jsonStr = jsonStr.replace("https\": \"", "https:");
            jsonStr = jsonStr.replace("http\": \"", "http:");
            //Log.e("map",jsonStr);
            try {
                ObjectMapper objectMapper = new ObjectMapper();
                JsonNode jsonNode = objectMapper.readTree(jsonStr);
                String nameOfScence = jsonNode.get("nameOfScence").asText();
                double latitude = Double.parseDouble(jsonNode.get("latitude").asText());
                double longitude = Double.parseDouble(jsonNode.get("longitude").asText());
                String des = jsonNode.get("des").asText();
                imageUrl = jsonNode.get("picURL").asText();
                Log.e("pointURL",imageUrl);
                LatLng latLng = new LatLng(latitude,longitude);
                MarkerOptions markerOptions = new MarkerOptions();
                markerOptions.icon(BitmapDescriptorFactory.fromResource(R.drawable.location));
                markerOptions.position(latLng);
                markerOptions.title(nameOfScence);
                markerOptions.snippet(des);
                marker = aMap.addMarker(markerOptions);
                //aMap.setInfoWindowAdapter(this);
                setCenter(marker);
                marker.showInfoWindow();
                if(pendingResult != null){
                    pendingResult.success(true);
                }
            }catch(Exception e){
                Log.e("InjectOnePoint", String.valueOf(e));
                if(pendingResult != null){
                    pendingResult.success(false);
                }
            }
        }
    }

    private void setCenter(Marker marker){
        aMap.animateCamera(CameraUpdateFactory.newCameraPosition(new CameraPosition(marker.getPosition(),16,30,0)));
    }

    @Override
    public boolean onMarkerClick(Marker marker) {
        setCenter(marker);
        if(marker.isInfoWindowShown()){
            marker.hideInfoWindow();
        } else {
            marker.showInfoWindow();
        }
        return true;
    }

    @Override
    public View getInfoWindow(Marker marker) {
        //nativeView = LayoutInflater.from(this).inflate(R.layout.infowindow, null);
        TextView titleTextView = nativeView.findViewById(R.id.titleTextView);
        TextView contentTextView = nativeView.findViewById(R.id.contentTextView);
        titleTextView.setText(marker.getTitle());
        contentTextView.setText(marker.getSnippet());
        imageView = nativeView.findViewById(R.id.myImageView);
        if (imageUrl == null || imageUrl.isEmpty()) {
            Log.e("map", "清除图片缓存");
            imageView.setImageBitmap(null); // 清除图片
            imageView.setVisibility(View.GONE); // 隐藏 ImageView
        } else {
            if(imageView.getVisibility() == View.GONE){
                imageView.setVisibility(View.VISIBLE);
            }
            // 正常加载图片
            Log.e("map", "加载图片");
            ImageLoader.ImageListener imageListener = ImageLoader.getImageListener(
                    imageView,
                    0, // 默认图片
                    0  // 失败图片
            );
            imageLoader.get(imageUrl, imageListener);
        }
//        ImageLoader.ImageListener imageListener = ImageLoader.getImageListener(
//                imageView,
//                R.drawable.touming, // 默认图片
//                R.drawable.touming); // 加载失败时的图片
//        imageLoader.get(imageUrl, imageListener);
        return nativeView;
    }

    @Override
    public View getInfoContents(Marker marker) {
        return null;
    }

    @Override
    public void onPoiSearched(PoiResult poiResult, int i) {
        if(i == 1000){
            Log.e("map", "查询数据返回");
            ArrayList points = new ArrayList<>();
            ObjectMapper objectMapper = new ObjectMapper();
            ArrayList<PoiItem> pois = poiResult.getPois();
            for(int j=0; j < pois.size(); j++){
                ObjectNode jsonNode = objectMapper.createObjectNode();
                jsonNode.put("nameOfScence", pois.get(j).getTitle());
                jsonNode.put("longitude",  pois.get(j).getLatLonPoint().getLongitude());
                jsonNode.put("latitude", pois.get(j).getLatLonPoint().getLatitude());
                points.add(jsonNode);
            }
            try {
                methodChannel.invokeMethod("findPOIResults",objectMapper.writeValueAsString(points));
            } catch (JsonProcessingException e) {
                e.printStackTrace();
            }
        } else {
            Log.e("map", "error");
            methodChannel.invokeMethod("findPOIResults","error");
        }
    }

    @Override
    public void onPoiItemSearched(PoiItem poiItem, int i) {
        Log.e("map", String.valueOf(poiItem));
    }
}
