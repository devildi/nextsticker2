package com.example.nextsticker2;

import static com.tekartik.sqflite.Constant.TAG;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.ImageView;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.platform.PlatformView;

import com.android.volley.RequestQueue;
import com.android.volley.toolbox.ImageLoader;
import com.android.volley.toolbox.Volley;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.google.android.gms.common.api.ApiException;
import com.google.android.gms.maps.CameraUpdateFactory;
import com.google.android.gms.maps.GoogleMap;
import com.google.android.gms.maps.GoogleMapOptions;
import com.google.android.gms.maps.MapView;
import com.google.android.gms.maps.OnMapReadyCallback;
import com.google.android.gms.maps.UiSettings;
import com.google.android.gms.maps.model.BitmapDescriptorFactory;
import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.Marker;
import com.google.android.gms.maps.model.MarkerOptions;
import com.google.android.gms.maps.model.Polyline;
import com.google.android.gms.maps.model.PolylineOptions;
import com.google.android.libraries.places.api.Places;
import com.google.android.libraries.places.api.model.AutocompletePrediction;
import com.google.android.libraries.places.api.net.FindAutocompletePredictionsRequest;
import com.google.android.libraries.places.api.net.PlacesClient;

import org.jetbrains.annotations.NotNull;

import com.google.android.libraries.places.api.model.Place;
import com.google.android.libraries.places.api.net.FetchPlaceRequest;
import com.google.android.libraries.places.api.net.FetchPlaceResponse;
import com.google.android.libraries.places.api.net.PlacesClient;
import com.google.android.gms.tasks.OnFailureListener;
import com.google.android.gms.tasks.OnSuccessListener;
import com.google.android.gms.maps.model.LatLng;

class GoogleDesign<MapActivity, FusedLocationProviderClient> extends AppCompatActivity implements PlatformView, GoogleMap.OnMapClickListener, OnMapReadyCallback, GoogleMap.OnMarkerClickListener, MethodChannel.MethodCallHandler, ActivityCompat.OnRequestPermissionsResultCallback,GoogleMap.OnInfoWindowClickListener, GoogleMap.InfoWindowAdapter {
    MapView mapView;
    Context context1 = null;
    String imageUrl;
    //private final View nativeView;
    ImageView imageView;
    ImageLoader imageLoader;
    RequestQueue requestQueue;
    Activity activity1 = null;
    MethodChannel methodChannel;
    GoogleMap map;
    String points;
    ArrayList<Marker> pointsArray = new ArrayList<Marker>();
    Marker destination = null;
    LatLng depart = null;
    List<Polyline> polyLines = new ArrayList<Polyline>();
    ArrayList<Marker> trans = new ArrayList<Marker>();
    List<PolylineOptions> polyLinesArray = new ArrayList<PolylineOptions>();
    List<MarkerOptions> markerOptionsArray = new ArrayList<MarkerOptions>();
    private FusedLocationProviderClient fusedLocationClient;
    private PlacesClient placesClient;


    GoogleDesign( Context context, BinaryMessenger messenger, int id, Map<String, Object> creationParams, Activity activity) {
        methodChannel = new MethodChannel(messenger, "gaode_native_channel");
        methodChannel.setMethodCallHandler(this);
        //nativeView = LayoutInflater.from(context).inflate(R.layout.infowindow, null);
        context1 = context;
        activity1 = activity;
        if (!Places.isInitialized()) {
            Places.initialize(context1.getApplicationContext(), "AIzaSyB5LS2bbGE_Iw1e7Dc3_al7glDliILip_c");
        }
        if (activity1 != null) {
            placesClient = Places.createClient(activity1);
        } else {
            placesClient = Places.createClient(context1.getApplicationContext());
        }
        authority();
        //locationOnce(activity1);
        points = creationParams.get("pointsString").toString();
        if (mapView != null) {
            mapView.onResume();
        }
        GoogleMapOptions options = new GoogleMapOptions();
        options.compassEnabled(true).rotateGesturesEnabled(true).tiltGesturesEnabled(true);
        mapView = new MapView(context, options);
        mapView.onCreate(new Bundle());
        mapView.getMapAsync(this);
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

    }

    @Override
    public View getView() {
        mapView.onResume();
        return mapView;
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        mapView.onDestroy();
    }

    @Override
    protected void onResume() {
        super.onResume();
        mapView.onResume();
    }

    @Override
    public void onLowMemory() {
        super.onLowMemory();
        mapView.onLowMemory();
    }

    @Override
    protected void onStart() {
        super.onStart();
        mapView.onStart();
    }

    @Override
    protected void onStop() {
        super.onStop();
        mapView.onStop();
    }


    @Override
    public void dispose() {
        mapView.onPause();
    }

    @SuppressLint("MissingPermission")
    @Override
    public void onMapReady(@NonNull GoogleMap googleMap) {
        Log.e("AmapErr", "地图渲染完成：显示地图，加载points");
        map = googleMap;
        if(depart != null){
            googleMap.moveCamera(CameraUpdateFactory.newLatLng(new LatLng(depart.latitude, depart.longitude)));
        } else {
            googleMap.moveCamera(CameraUpdateFactory.newLatLng(new LatLng(41.80, 123.46)));
        }
        googleMap.moveCamera(CameraUpdateFactory.zoomTo(15));
        initData(points);
        googleMap.setOnMarkerClickListener(this);
        UiSettings mUiSettings = googleMap.getUiSettings();
        mUiSettings.setCompassEnabled(true);
        mUiSettings.setMyLocationButtonEnabled(false);
        mUiSettings.setMapToolbarEnabled(false);
        map.setOnInfoWindowClickListener(this);
        googleMap.setInfoWindowAdapter(this);
    }

    private void initData(String pointString) {
        map.clear();
        Log.e("map", "开始渲染点坐标");
        Log.e("点坐标数据", pointString);
        String jsonStr = pointString.replace("{", "{\"");
        jsonStr = jsonStr.replace(": ", "\":\"");
        jsonStr = jsonStr.replace(", ", "\",\"");
        jsonStr = jsonStr.replace("}", "\"}");
        jsonStr = jsonStr.replace("https\": \"", "https:");
        jsonStr = jsonStr.replace("http\": \"", "http:");

        try {
            ObjectMapper objectMapper = new ObjectMapper();
            JsonNode jsonNode = objectMapper.readTree(jsonStr);
            String nameOfScence = jsonNode.get("nameOfScence").asText();
            double latitude = Double.parseDouble(jsonNode.get("latitude").asText());
            double longitude = Double.parseDouble(jsonNode.get("longitude").asText());
            String des = jsonNode.get("des").asText();
            imageUrl = jsonNode.get("picURL").asText();
            LatLng latLng = new LatLng(latitude, longitude);
            MarkerOptions markerOptions = new MarkerOptions();
            markerOptions.position(latLng);
            markerOptions.title(nameOfScence);
            markerOptions.snippet(des);
            //markerOptions.snippet(Integer.toString(category) + "#" + Boolean.toString(done));
            Marker marker = map.addMarker(markerOptions);
            marker.setTag(imageUrl);
            assert marker != null;
            setCenter(marker);
            marker.showInfoWindow();
        } catch (Exception e) {

        }
    }

    public void authority() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (context1.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                //如果应用之前请求过此权限但用户拒绝了请求，此方法将返回 true。
                Log.e("quanxian", "权限");
                if (ActivityCompat.shouldShowRequestPermissionRationale(activity1, Manifest.permission.ACCESS_COARSE_LOCATION)) {
                    //这里可以写个对话框之类的项向用户解释为什么要申请权限，并在对话框的确认键后续再次申请权限.它在用户选择"不再询问"的情况下返回false

                } else {
                    //申请权限，字符串数组内是一个或多个要申请的权限，1是申请权限结果的返回参数，在onRequestPermissionsResult可以得知申请结果
                    ActivityCompat.requestPermissions(activity1, new String[]{Manifest.permission.ACCESS_COARSE_LOCATION, Manifest.permission.ACCESS_FINE_LOCATION}, 1);
                }
            }
        }
    }

    public void setCenter(@NotNull Marker marker) {
        map.animateCamera(CameraUpdateFactory.newLatLngZoom(new LatLng(marker.getPosition().latitude, marker.getPosition().longitude), 15));
    }

    @Override
    public void onMethodCall(@NotNull MethodCall call, @NotNull MethodChannel.Result result) {
        if ("startLoaction".equals(call.method)) {
            Log.e("点击", call.method);
            //locationOnce(activity1);
        } else if ("findPOI".equals(call.method)) {
            String query = (String) call.arguments;
            Log.e("findPOI", query);
            FindAutocompletePredictionsRequest request = FindAutocompletePredictionsRequest.builder()
                    .setQuery(query)
                    .build();

            placesClient.findAutocompletePredictions(request)
                    .addOnSuccessListener((response) -> {
                        for (AutocompletePrediction prediction : response.getAutocompletePredictions()) {
                            fetchPlaceDetails(prediction.getPlaceId());
                            break; // 仅处理第一个结果
                        }
                    })
                    .addOnFailureListener((exception) -> {
                        if (exception instanceof ApiException) {
                            ApiException apiException = (ApiException) exception;
                            Log.e(TAG, "Place not found: " + apiException.getStatusCode());
                        }
                    });
            result.success(query);
        } else if ("InjectData".equals(call.method)) {
            String text = (String) call.arguments;
            Log.e("amap", "InjectData");
            if (!pointsArray.isEmpty()) {
                map.clear();
                pointsArray.clear();
            };
            initData(text);
        } else if ("setDestination".equals(call.method)) {

        } else if ("getPoster".equals(call.method)) {

        } else if ("clear".equals(call.method)) {
            map.clear();
        } else if ("InjectOnePoint".equals(call.method)) {
            String pointString = (String) call.arguments;
            Log.e("amap", pointString);
            initData(pointString);
        }else if ("notification".equals(call.method)) {
            String text = (String) call.arguments;

        }else if ("openSysLocationPage".equals(call.method)) {


        } else if ("check".equals(call.method)) {

        }
    }

    private void fetchPlaceDetails(String placeId) {
        // 1. 指定要返回的字段（必须包含 LAT_LNG）
        final List<Place.Field> placeFields = Arrays.asList(
                Place.Field.LAT_LNG,  // 经纬度
                Place.Field.NAME,     // 地点名称
                Place.Field.ADDRESS   // 地址
        );

        // 2. 构建请求
        final FetchPlaceRequest request = FetchPlaceRequest.newInstance(placeId, placeFields);

        // 3. 调用 PlacesClient 获取详情
        placesClient.fetchPlace(request)
                .addOnSuccessListener(new OnSuccessListener<FetchPlaceResponse>() {
                    @Override
                    public void onSuccess(FetchPlaceResponse response) {
                        Place place = response.getPlace();

                        // 获取经纬度
                        LatLng latLng = place.getLatLng();
                        String name = place.getName();
                        String address = place.getAddress();

                        Log.d("PlaceDetails", "名称: " + name);
                        Log.d("PlaceDetails", "地址: " + address);
                        Log.d("PlaceDetails", "经纬度: " + latLng);
                        ArrayList points = new ArrayList<>();
                        ObjectMapper objectMapper = new ObjectMapper();
                        ObjectNode jsonNode = objectMapper.createObjectNode();
                        jsonNode.put("nameOfScence", name);
                        jsonNode.put("longitude",  latLng.longitude);
                        jsonNode.put("latitude", latLng.latitude);
                        points.add(jsonNode);
                        try {
                            methodChannel.invokeMethod("findPOIResults",objectMapper.writeValueAsString(points));
                        } catch (JsonProcessingException e) {
                            e.printStackTrace();
                        }
                        // 在地图上标记位置（示例）
//                        if (map != null && latLng != null) {
//                            map.addMarker(new MarkerOptions()
//                                    .position(latLng)
//                                    .title(name));
//                            map.moveCamera(CameraUpdateFactory.newLatLngZoom(latLng, 15));
//                        }
                    }
                })
                .addOnFailureListener(new OnFailureListener() {
                    @Override
                    public void onFailure(@NonNull Exception e) {
                        Log.e("PlaceDetails", "获取地点详情失败: " + e.getMessage());
                    }
                });
    }
    @Override
    public boolean onMarkerClick(@NotNull Marker marker) {
        Log.e("点击","图标");
        boolean s = marker.isInfoWindowShown();
        Log.e("点击", String.valueOf(s));
        setCenter(marker);
        if(marker.isInfoWindowShown()){
            marker.hideInfoWindow();
        } else {
            marker.showInfoWindow();
        }
        return true;
    }
    @Override
    public void onMapClick(@NotNull LatLng latLng) {
        Log.e("mapClick", "mapClick");
        if(!trans.isEmpty()){
            for(Marker marker:trans){
                if(marker.isInfoWindowShown()){
                    marker.hideInfoWindow();
                }
            }
        }
    }

    @Override
    public void onInfoWindowClick(@NonNull Marker marker) {
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
    }

    @Nullable
    @Override
    public View getInfoContents(@NonNull Marker marker) {
        return null;
    }

    @Nullable
    @Override
    public View getInfoWindow(@NonNull Marker marker) {
        View nativeView = LayoutInflater.from(context1).inflate(R.layout.infowindow, null);
        TextView titleTextView = nativeView.findViewById(R.id.titleTextView);
        TextView contentTextView = nativeView.findViewById(R.id.contentTextView);
        titleTextView.setText(marker.getTitle());
        contentTextView.setText(marker.getSnippet());
        imageView = nativeView.findViewById(R.id.myImageView);
        String url = (String)marker.getTag();
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
        return nativeView;
    }
}