package com.example.nextsticker2;

import static android.content.Context.NOTIFICATION_SERVICE;

import android.Manifest;
import android.app.Activity;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.location.Location;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.util.Log;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;

import com.amap.api.location.AMapLocation;
import com.amap.api.location.AMapLocationClient;
import com.amap.api.location.AMapLocationClientOption;
import com.amap.api.location.AMapLocationListener;
import com.amap.api.maps.AMap;
import com.amap.api.maps.AMapOptions;
import com.amap.api.maps.CameraUpdateFactory;
import com.amap.api.maps.MapView;
import com.amap.api.maps.MapsInitializer;
import com.amap.api.maps.UiSettings;
import com.amap.api.maps.model.BitmapDescriptorFactory;
import com.amap.api.maps.model.CameraPosition;
import com.amap.api.maps.model.CustomMapStyleOptions;
import com.amap.api.maps.model.LatLng;
import com.amap.api.maps.model.LatLngBounds;
import com.amap.api.maps.model.Marker;
import com.amap.api.maps.model.MarkerOptions;
import com.amap.api.maps.model.MyLocationStyle;
import com.amap.api.maps.model.Polyline;
import com.amap.api.maps.model.PolylineOptions;
import com.amap.api.services.busline.BusStationItem;
import com.amap.api.services.core.AMapException;
import com.amap.api.services.core.LatLonPoint;
import com.amap.api.services.core.ServiceSettings;
import com.amap.api.services.route.BusPath;
import com.amap.api.services.route.BusRouteResult;
import com.amap.api.services.route.BusStep;
import com.amap.api.services.route.DrivePath;
import com.amap.api.services.route.DriveRouteResult;
import com.amap.api.services.route.RidePath;
import com.amap.api.services.route.RideRouteResult;
import com.amap.api.services.route.RouteBusLineItem;
import com.amap.api.services.route.RouteBusWalkItem;
import com.amap.api.services.route.RouteRailwayItem;
import com.amap.api.services.route.RouteSearch;
import com.amap.api.services.route.WalkPath;
import com.amap.api.services.route.WalkRouteResult;

import org.json.JSONArray;
import org.json.JSONObject;

import io.flutter.FlutterInjector;
import io.flutter.embedding.engine.loader.FlutterLoader;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.platform.PlatformView;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

class NativeView implements PlatformView, MethodChannel.MethodCallHandler, RouteSearch.OnRouteSearchListener, AMap.OnMapClickListener, AMap.OnMarkerClickListener,AMap.OnMyLocationChangeListener  {
    //@NonNull private final TextView textView;
    Context context1 = null;
    Activity activity1 = null;
    private final FrameLayout container;  // 根布局容器
    private MapView mapView;
    private AMap aMap;
    private UiSettings mUiSettings;
    private RouteSearch mRouteSearch;
    private WalkRouteResult mWalkRouteResult;
    private DriveRouteResult mDriveRouteResult;
    private BusRouteResult mBusRouteResult;
    private RideRouteResult mRideRouteResult;
    MethodChannel methodChannel;
    private static final int STROKE_COLOR = Color.argb(180, 3, 145, 255);
    private static final int FILL_COLOR = Color.argb(10, 0, 0, 180);
    private MyLocationStyle myLocationStyle;
    ArrayList<Marker> pointsArray = new ArrayList<Marker>();
    Marker destination = null;
    LatLonPoint depart = null;
    LatLonPoint departPoint = new LatLonPoint(0,0);
    LatLonPoint desPoint = null;
    public List<Polyline> PolyLines = new ArrayList<Polyline>();
    ArrayList<Marker> trans = new ArrayList<Marker>();
    Boolean byTrain = false;
    public AMapLocationClient mLocationClient = null;
    public AMapLocationClientOption mLocationOption = null;

    private boolean isValidLocation(double lat, double lon) {
        return lat >= -90.0 && lat <= 90.0 && lon >= -180.0 && lon <= 180.0 && (lat != 0.0 || lon != 0.0);
    }

    private double getDistance(double lat1, double lon1, double lat2, double lon2) {
        double R = 6371000; // Earth radius in meters
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                   Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
                   Math.sin(dLon / 2) * Math.sin(dLon / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    }

    public AMapLocationListener mLocationListener = new AMapLocationListener() {
        @Override
        public void onLocationChanged(AMapLocation aMapLocation) {
            if (aMapLocation != null && aMapLocation.getErrorCode() == 0) {
                Log.e("AmapErr","定位成功");
                double newLat = aMapLocation.getLatitude();
                double newLon = aMapLocation.getLongitude();
                if (isValidLocation(newLat, newLon)) {
                    android.content.SharedPreferences sharedPref = context1.getSharedPreferences("LocationCache", Context.MODE_PRIVATE);
                    double cachedLat = Double.longBitsToDouble(sharedPref.getLong("cached_lat", Double.doubleToLongBits(0.0)));
                    double cachedLon = Double.longBitsToDouble(sharedPref.getLong("cached_lon", Double.doubleToLongBits(0.0)));
                    if (cachedLat == 0.0 || cachedLon == 0.0 || getDistance(cachedLat, cachedLon, newLat, newLon) > 500.0) {
                        android.content.SharedPreferences.Editor editor = sharedPref.edit();
                        editor.putLong("cached_lat", Double.doubleToRawLongBits(newLat));
                        editor.putLong("cached_lon", Double.doubleToRawLongBits(newLon));
                        editor.apply();
                        Log.e("LocationCache", "Location cache updated: " + newLat + ", " + newLon);
                    }
                }
                depart = new LatLonPoint(newLat, newLon);
                aMap.animateCamera(CameraUpdateFactory.newCameraPosition(new CameraPosition(new LatLng(newLat, newLon),16,30,0)));
            } else {
                String errText = "定位失败~~~~~~," + aMapLocation.getErrorCode()+ ": " + aMapLocation.getErrorInfo();
                Log.e("AmapErr",errText);
            }
        }
    };

    String channelId = "test";
    String channelName = "测试通知";
    NotificationManager notificationManager;
    Notification.Builder builder;
    NotificationChannel channel;
    NativeView(Context context, BinaryMessenger messenger, int id, Map<String, Object> creationParams, Activity activity) {
        container = new FrameLayout(context);
        container.setLayoutParams(new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
        ));
        MapsInitializer.updatePrivacyShow(context,true,true);
        MapsInitializer.updatePrivacyAgree(context,true);
        ServiceSettings.updatePrivacyShow(context,true,true);
        ServiceSettings.updatePrivacyAgree(context,true);
        FlutterLoader loader = FlutterInjector.instance().flutterLoader();
        methodChannel = new MethodChannel(messenger, "gaode_native_channel");
        MethodChannelManager.register(methodChannel, this);
        context1 = context;
        activity1 = activity;
        authority();
        String points = creationParams.get("pointsString").toString();
        //显示地图
        if(mapView != null){
            mapView.onResume();
        }
        Log.e("map","地图初始化");
        
        android.content.SharedPreferences sharedPref = context.getSharedPreferences("LocationCache", Context.MODE_PRIVATE);
        double cachedLat = Double.longBitsToDouble(sharedPref.getLong("cached_lat", Double.doubleToLongBits(0.0)));
        double cachedLon = Double.longBitsToDouble(sharedPref.getLong("cached_lon", Double.doubleToLongBits(0.0)));
        if (isValidLocation(cachedLat, cachedLon)) {
            depart = new LatLonPoint(cachedLat, cachedLon);
        }

        AMapOptions mapOptions = new AMapOptions();
        if(depart != null){
            mapOptions.camera(new CameraPosition(new LatLng(depart.getLatitude(),depart.getLongitude()), 16f, 30, 0));
            mapView = new MapView(context, mapOptions);
        } else {
            mapView = new MapView(context);
        }
        container.addView(mapView);
        mapView.onCreate(new Bundle());
        if (aMap == null) {
            aMap = mapView.getMap();
            aMap.addOnMapClickListener(this);
            aMap.addOnMyLocationChangeListener(this);
            aMap.setOnMapLoadedListener(() -> {
                try {
                    InputStream styleDataStream = context1.getAssets().open("flutter_assets/assets/style.data");
                    InputStream styleExtraStream = context1.getAssets().open("flutter_assets/assets/style_extra.data");

                    byte[] styleData = readBytes(styleDataStream);
                    byte[] styleExtraData = readBytes(styleExtraStream);

                    CustomMapStyleOptions customMapStyle = new CustomMapStyleOptions();
                    customMapStyle.setEnable(true);
                    customMapStyle.setStyleData(styleData);
                    customMapStyle.setStyleExtraData(styleExtraData);

                    aMap.setCustomMapStyle(customMapStyle);

                } catch (Exception e) {
                    Log.e("MapStyle", "设置地图样式时发生错误: " + e.getMessage());
                    e.printStackTrace();
                }
            });
        }
        //地图控件
        mUiSettings = aMap.getUiSettings();
        mUiSettings.setZoomControlsEnabled(false);
        mUiSettings.setRotateGesturesEnabled(false);
        mUiSettings.setTiltGesturesEnabled(false);
        //定位
        aMap.setMyLocationEnabled(true);
        setupLocationStyle();
        try {
            mLocationClient = new AMapLocationClient(context);
            mLocationClient.setLocationListener(mLocationListener);

            mLocationOption = new AMapLocationClientOption();
            mLocationOption.setLocationMode(AMapLocationClientOption.AMapLocationMode.Hight_Accuracy);
            //设置单词或连续定位
            mLocationOption.setOnceLocation(true);

            boolean hasPermission = true;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                hasPermission = (context1.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED);
            }
            if (hasPermission) {
                locationOnce();
            }
        }catch (Exception e){
            e.printStackTrace();
        }
        //显示点标记
        //Log.e("map",points);
        initData(points);
        try {
            mRouteSearch = new RouteSearch(context);
            mRouteSearch.setRouteSearchListener(this);
        } catch (AMapException e) {
            e.printStackTrace();
        }
        aMap.addOnMarkerClickListener(this);
        notificationManager = (NotificationManager) activity1.getSystemService(NOTIFICATION_SERVICE);
        if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O){
            //如果大于26
            channel = new NotificationChannel(channelId,channelName,NotificationManager.IMPORTANCE_HIGH);
            channel.canShowBadge();
            notificationManager.createNotificationChannel(channel);
            builder = new Notification.Builder(activity1,channelId);
            builder.setSmallIcon(R.drawable.location); //小图标
            builder.setAutoCancel(true); //自动quxiao
            builder.setContentTitle("NextSticker有新用户！");
            builder.setWhen(System.currentTimeMillis());//时间
        }
    }

    private byte[] readBytes(InputStream inputStream) throws IOException {
        ByteArrayOutputStream byteBuffer = new ByteArrayOutputStream();
        int bufferSize = 1024;
        byte[] buffer = new byte[bufferSize];
        int len;
        while ((len = inputStream.read(buffer)) != -1) {
            byteBuffer.write(buffer, 0, len);
        }
        return byteBuffer.toByteArray();
    }

    private void locationOnce() {
        if(null != mLocationClient){
            mLocationClient.setLocationOption(mLocationOption);
            mLocationClient.startLocation();
        }

        //aMap.animateCamera(CameraUpdateFactory.newCameraPosition(new CameraPosition(new LatLng(depart.getLatitude(), depart.getLongitude()),16,30,0)));
    }

    private void setupLocationStyle() {
        // 自定义系统定位蓝点
        MyLocationStyle myLocationStyle = new MyLocationStyle();
        // 自定义定位蓝点图标
        myLocationStyle.myLocationIcon(BitmapDescriptorFactory.fromResource(R.drawable.gps_point));
        // 自定义精度范围的圆形边框颜色
        myLocationStyle.strokeColor(STROKE_COLOR);
        //自定义精度范围的圆形边框宽度
        myLocationStyle.strokeWidth(5);
        // 设置圆形的填充颜色
        myLocationStyle.radiusFillColor(FILL_COLOR);
        myLocationStyle.myLocationType(MyLocationStyle.LOCATION_TYPE_LOCATION_ROTATE_NO_CENTER);
        // 将自定义的 myLocationStyle 对象添加到地图上
        aMap.setMyLocationStyle(myLocationStyle);
    }

    private void initData(String jsonData) {
        Log.e("map","开始渲染点坐标");
        try{
            JSONArray jsonArray = new JSONArray(jsonData);
            for (int i=0; i < jsonArray.length(); i++)    {
                try {
                    JSONObject jsonObject = jsonArray.getJSONObject(i);
                    String nameOfScence = jsonObject.optString("nameOfScence", "");
                    int category = jsonObject.optInt("category", 0);
                    boolean done = jsonObject.optBoolean("done", false);

                    String latStr = jsonObject.optString("latitude", "");
                    String lonStr = jsonObject.optString("longitude", "");
                    double latitude = 0.0;
                    double longitude = 0.0;
                    boolean hasCoords = false;

                    if (!latStr.isEmpty() && !lonStr.isEmpty()) {
                        try {
                            latitude = Double.parseDouble(latStr);
                            longitude = Double.parseDouble(lonStr);
                            hasCoords = (latitude != 0.0 || longitude != 0.0);
                        } catch (NumberFormatException e) {
                            hasCoords = false;
                        }
                    }

                    LatLng latLng = new LatLng(latitude, longitude);
                    MarkerOptions markerOptions = new MarkerOptions();
                    if(category == 0){
                        if(!done){
                            markerOptions.icon(BitmapDescriptorFactory.fromResource(R.drawable.location));
                        } else {
                            markerOptions.icon(BitmapDescriptorFactory.fromResource(R.drawable.amap_through));
                        }
                    } else if(category == 1){
                        markerOptions.icon(BitmapDescriptorFactory.fromResource(R.drawable.hotel));
                    } else if(category == 2){
                        markerOptions.icon(BitmapDescriptorFactory.fromResource(R.drawable.food));
                    }
                    markerOptions.position(latLng);
                    markerOptions.title(nameOfScence);
                    markerOptions.snippet(Integer.toString(category) + "#" + Boolean.toString(done));
                    markerOptions.visible(hasCoords);
                    Marker marker = aMap.addMarker(markerOptions);
                    pointsArray.add(marker);
                } catch(Exception e) {
                    Log.e("amap", "渲染单个点坐标异常: " + e.getMessage());
                }
            }
        } catch(Exception e){
            Log.e("amap", "渲染点坐标异常: " + e.getMessage());
        }
    }

    private void authority() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (context1.checkSelfPermission(android.Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                Log.e("quanxian","请求定位权限");
                android.content.SharedPreferences sharedPref = context1.getSharedPreferences("LocationCache", Context.MODE_PRIVATE);
                sharedPref.edit().putBoolean("permission_requested", true).apply();
                ActivityCompat.requestPermissions(activity1, new String[]{android.Manifest.permission.ACCESS_COARSE_LOCATION, Manifest.permission.ACCESS_FINE_LOCATION}, 1);
            }
        }
    }

    private void setCenter(Marker marker){
        if (marker != null && marker.getPosition() != null) {
            LatLng pos = marker.getPosition();
            if (pos.latitude != 0.0 || pos.longitude != 0.0) {
                aMap.animateCamera(CameraUpdateFactory.newCameraPosition(new CameraPosition(pos, 16, 30, 0)));
            }
        }
    }

    @NonNull
    @Override
    public View getView() {
//        Log.e("AmapErr","显示地图");
//        mapView.onResume();
//        return mapView;
        return container;
    }

    public void onResume() {
        if (mapView != null) mapView.onResume();
    }

    public void onPause() {
        if (mapView != null) mapView.onPause();
    }

    public void onDestroy() {
        if (mapView != null) mapView.onDestroy();
    }

    @Override
    public void dispose() {
//        Log.e("AmapErr","fugai 地图");
//        mapView.onPause();
        if (mapView != null) {
            mapView.onDestroy();  // 正确释放地图资源
            container.removeAllViews();  // 清理视图层次
        }
        MethodChannelManager.unregister(this);
    }

    @Override
    public void onMapClick(LatLng latLng) {
        Log.e("mapClick", "mapClick");
        if(trans.size() > 0){
            for(Marker marker:trans){
                if(marker.isInfoWindowShown()){
                    marker.hideInfoWindow();
                }
            }
        }
    }

    @Override
    public boolean onMarkerClick(Marker marker) {
        //Log.e("amap",(String)(marker.getSnippet()));
        Log.e("amap","点击图标");
        if(marker.getSnippet()!= null){
            if(marker.getSnippet().contains("#")){
                Log.e("amap",(String)(marker.getTitle()));
                setCenter(marker);
                destination = marker;
                int index = pointsArray.indexOf(marker);
                if (index != -1) {
                    methodChannel.invokeMethod("openBottomSheet", index);
                } else {
                    methodChannel.invokeMethod("openBottomSheet", marker.getTitle());
                }
            } else {
                if(marker.isInfoWindowShown()){
                    marker.hideInfoWindow();
                }else{
                    marker.showInfoWindow();
                }
            }
        } else {
            remove(PolyLines, trans);
            aMap.animateCamera(CameraUpdateFactory.newCameraPosition(new CameraPosition(new LatLng(depart.getLatitude(), depart.getLongitude()),16,30,0)));
            methodChannel.invokeMethod("clearInfor",null);
        }
        return true;
    }

    @Override
    public void onMyLocationChange(Location location) {
        if(location.getLongitude() == 0.0 && location.getLongitude() == 0.0){
            //Log.e("onMyLocationChange","请获取定位权限");
        } else {
            depart = new LatLonPoint(location.getLatitude(),location.getLongitude());
        }
    }

    @Override
    public void onBusRouteSearched(BusRouteResult result, int errorCode) {
        byTrain = false;
        Log.e("BusRouteResult", "公交地铁结果");
        methodChannel.invokeMethod("stopLoadingRoute",true);
        remove(PolyLines, trans);
        if (errorCode == AMapException.CODE_AMAP_SUCCESS) {
            if (result != null && result.getPaths() != null) {
                if (result.getPaths().size() > 0) {
                    mBusRouteResult = result;
                    final BusPath busPath = mBusRouteResult.getPaths().get(0);

                    int dis = (int) busPath.getWalkDistance();
                    int dur = (int) busPath.getDuration();
                    int cost = (int) busPath.getCost();
                    List<BusStep> steps = busPath.getSteps();

                    for (BusStep step : steps) {
                        RouteRailwayItem railDetail = step.getRailway();
                        if(railDetail != null){
                            byTrain = true;
                        }
                        RouteBusWalkItem walkDetail = step.getWalk();
                        if(walkDetail != null){
                            List<LatLng> latLngs = new ArrayList<LatLng>();
                            List<LatLonPoint> pois = walkDetail.getPolyline();
                            for (LatLonPoint poi: pois){
                                latLngs.add(new LatLng(poi.getLatitude(),poi.getLongitude()));
                            }
                            Polyline polyline =aMap.addPolyline(
                                    new PolylineOptions()
                                            .addAll(latLngs)
                                            .width(30f)
                                            .setCustomTexture(BitmapDescriptorFactory.fromResource(R.drawable.custtexture_slow)));
                            PolyLines.add(polyline);
                        }
                        List<RouteBusLineItem> busStopList = step.getBusLines();
                        if(busStopList.size() > 0){
                            RouteBusLineItem item = busStopList.get(0);

                            BusStationItem dapartStop = item.getDepartureBusStation();
                            String dapartStopName = dapartStop.getBusStationName();
                            LatLonPoint dapartStopLocation = dapartStop.getLatLonPoint();

                            BusStationItem arrStop = item.getArrivalBusStation();
                            String arrStopName = arrStop.getBusStationName();
                            LatLonPoint arrStopLocation = arrStop.getLatLonPoint();

                            String tilte = item.getBusLineName();
                            Marker departMarker = aMap.addMarker(
                                    new MarkerOptions()
                                            .position(new LatLng(dapartStopLocation
                                                    .getLatitude(),dapartStopLocation
                                                    .getLongitude()))
                                            .title(dapartStopName + " 上车")
                                            .icon(BitmapDescriptorFactory.fromResource(R.drawable.trans))
                                            .snippet(tilte));
                            trans.add(departMarker);
                            Marker arrMarker = aMap.addMarker(
                                    new MarkerOptions()
                                            .position(new LatLng(arrStopLocation.getLatitude(),arrStopLocation.getLongitude()))
                                            .title(arrStopName + " 下车")
                                            .icon(BitmapDescriptorFactory.fromResource(R.drawable.trans))
                                            .snippet(tilte));
                            trans.add(arrMarker);

                            List<LatLng> latLngs = new ArrayList<LatLng>();
                            List<LatLonPoint> pois = item.getPolyline();
                            for (LatLonPoint poi: pois){
                                latLngs.add(new LatLng(poi.getLatitude(),poi.getLongitude()));
                            }
                            Polyline polyline =aMap.addPolyline(
                                    new PolylineOptions()
                                            .addAll(latLngs)
                                            .width(18f)
                                            .setCustomTexture(BitmapDescriptorFactory.fromResource(R.drawable.custtexture)));
                            PolyLines.add(polyline);
                        }

                    }
                    if(byTrain){
                        remove(PolyLines, trans);
                        methodChannel.invokeMethod("aMapSearchRequestError","暂不提供跨城公交方案！");
                        return;
                    }

                    zoomToSpan(departPoint, desPoint);

                    int result1 [] = new int[3];
                    result1[0] = cost;
                    result1[1] = dur;
                    result1[2] = dis;
                    methodChannel.invokeMethod("openSnackBarForBus",result1);
                } else if (result != null && result.getPaths() == null) {
                    methodChannel.invokeMethod("aMapSearchRequestError","");
                }
            } else {
                methodChannel.invokeMethod("aMapSearchRequestError","");
            }
        } else {
            methodChannel.invokeMethod("aMapSearchRequestError","");
        }
    }

    private void zoomToSpan(LatLonPoint departPoint, LatLonPoint desPoint) {
        if (departPoint != null) {
            if (aMap == null) {
                return;
            }
            try {
                LatLngBounds bounds = getLatLngBounds(departPoint, desPoint);
                aMap.animateCamera(CameraUpdateFactory
                        .newLatLngBounds(bounds, 100));
            } catch (Throwable e) {
                e.printStackTrace();
            }
        }
    }

    private LatLngBounds getLatLngBounds(LatLonPoint departPoint, LatLonPoint desPoint) {
        LatLngBounds.Builder b = LatLngBounds.builder();
        b.include(new LatLng(departPoint.getLatitude(), departPoint.getLongitude()));
        b.include(new LatLng(desPoint.getLatitude(), desPoint.getLongitude()));
        return b.build();
    }

    @Override
    public void onDriveRouteSearched(DriveRouteResult result, int errorCode) {
        Log.e("DriveRouteResult", "驾车结果");
        methodChannel.invokeMethod("stopLoadingRoute",true);
        if (errorCode == AMapException.CODE_AMAP_SUCCESS) {
            if (result != null && result.getPaths() != null) {
                if (result.getPaths().size() > 0) {
                    mDriveRouteResult = result;
                    final DrivePath drivePath = mDriveRouteResult.getPaths().get(0);
                    if(drivePath == null) {
                        return;
                    }

                    DrivingRouteOverlay drivingRouteOverlay = new DrivingRouteOverlay(
                            context1, aMap, drivePath,
                            mDriveRouteResult.getStartPos(),
                            mDriveRouteResult.getTargetPos(), null);
                    drivingRouteOverlay.setNodeIconVisibility(false);//设置节点marker是否显示
                    drivingRouteOverlay.setIsColorfulline(true);//是否用颜色展示交通拥堵情况，默认true
                    //drivingRouteOverlay.removeFromMap();
                    remove(PolyLines, trans);
                    drivingRouteOverlay.addToMap();
                    add(PolyLines, drivingRouteOverlay.allPolyLines);
                    drivingRouteOverlay.zoomToSpan();
                    int dis = (int) drivePath.getDistance();
                    int dur = (int) drivePath.getDuration();
                    int taxiCost = (int) mDriveRouteResult.getTaxiCost();
                    int result1 [] = new int[2];
                    result1[0] = dis;
                    result1[1] = dur;
                    methodChannel.invokeMethod("openSnackBar", result1);
                } else if (result != null && result.getPaths() == null) {
                    methodChannel.invokeMethod("aMapSearchRequestError","");
                }

            } else {
                methodChannel.invokeMethod("aMapSearchRequestError","");
            }
        } else {
            methodChannel.invokeMethod("aMapSearchRequestError","");
        }
    }

    @Override
    public void onWalkRouteSearched(WalkRouteResult result, int errorCode) {
        Log.e("walkRouteResult", "步行返回结果");
        methodChannel.invokeMethod("stopLoadingRoute",true);
        if (errorCode == AMapException.CODE_AMAP_SUCCESS) {
            if (result != null && result.getPaths() != null) {
                if (result.getPaths().size() > 0) {

                    mWalkRouteResult = result;
                    final WalkPath walkPath = mWalkRouteResult.getPaths().get(0);
                    if(walkPath == null) {
                        return;
                    }
                    WalkRouteOverlay walkRouteOverlay = new WalkRouteOverlay(
                            context1, aMap, walkPath,
                            mWalkRouteResult.getStartPos(),
                            mWalkRouteResult.getTargetPos());
                    remove(PolyLines, trans);
                    walkRouteOverlay.addToMap();
                    add(PolyLines, walkRouteOverlay.allPolyLines);
                    walkRouteOverlay.zoomToSpan();
                    int dis = (int) walkPath.getDistance();
                    int dur = (int) walkPath.getDuration();
                    int result1 [] = new int[2];
                    result1[0] = dis;
                    result1[1] = dur;
                    methodChannel.invokeMethod("openSnackBar", result1);

                } else if (result != null && result.getPaths() == null) {
                    methodChannel.invokeMethod("aMapSearchRequestError","");
                }
            } else {
                methodChannel.invokeMethod("aMapSearchRequestError","");
            }
        } else {
            methodChannel.invokeMethod("aMapSearchRequestError","");
        }
    }

    @Override
    public void onRideRouteSearched(RideRouteResult result, int errorCode) {
        methodChannel.invokeMethod("stopLoadingRoute",true);
        if (errorCode == AMapException.CODE_AMAP_SUCCESS) {
            if (result != null && result.getPaths() != null) {
                if (result.getPaths().size() > 0) {
                    mRideRouteResult = result;
                    final RidePath ridePath = mRideRouteResult.getPaths().get(0);
                    if(ridePath == null) {
                        return;
                    }
                    RideRouteOverlay rideRouteOverlay = new RideRouteOverlay(
                            context1, aMap, ridePath,
                            mRideRouteResult.getStartPos(),
                            mRideRouteResult.getTargetPos());
                    rideRouteOverlay.setNodeIconVisibility(false);

                    remove(PolyLines, trans);
                    rideRouteOverlay.addToMap();
                    add(PolyLines, rideRouteOverlay.allPolyLines);
                    rideRouteOverlay.zoomToSpan();

                    int dis = (int) ridePath.getDistance();
                    int dur = (int) ridePath.getDuration();
                    int result1 [] = new int[2];
                    result1[0] = dis;
                    result1[1] = dur;
                    methodChannel.invokeMethod("openSnackBar", result1);
                } else if (result != null && result.getPaths() == null) {
                    methodChannel.invokeMethod("aMapSearchRequestError","");
                }
            } else {
                methodChannel.invokeMethod("aMapSearchRequestError","");
            }
        } else {
            methodChannel.invokeMethod("aMapSearchRequestError","");
        }
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        if ("startLoaction".equals(call.method)) {
            String text = (String) call.arguments;
            Log.e("amap", "startLoaction");
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (context1.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                    android.content.SharedPreferences sharedPref = context1.getSharedPreferences("LocationCache", Context.MODE_PRIVATE);
                    boolean requestedBefore = sharedPref.getBoolean("permission_requested", false);
                    if (requestedBefore && !ActivityCompat.shouldShowRequestPermissionRationale(activity1, Manifest.permission.ACCESS_COARSE_LOCATION)) {
                        methodChannel.invokeMethod("alert", true);
                    } else {
                        sharedPref.edit().putBoolean("permission_requested", true).apply();
                        ActivityCompat.requestPermissions(activity1, new String[]{Manifest.permission.ACCESS_COARSE_LOCATION, Manifest.permission.ACCESS_FINE_LOCATION}, 1);
                    }
                    return;
                }
            }
            locationOnce();
        } else if ("genRoute".equals(call.method)) {
            if(null != depart){
                departPoint = new LatLonPoint(depart.getLatitude(),depart.getLongitude());
            } else {
                departPoint = new LatLonPoint(0,0);
            }
            desPoint = new LatLonPoint(destination.getPosition().latitude,destination.getPosition().longitude);
            String text = (String) call.arguments;
            Log.e("genRoute", text);
            final RouteSearch.FromAndTo fromAndTo = new RouteSearch.FromAndTo(departPoint, desPoint);
            methodChannel.invokeMethod("isLoadingRoute",true);
            if(text.equals("bike")) {
                RouteSearch.RideRouteQuery query = new RouteSearch.RideRouteQuery(fromAndTo);
                mRouteSearch.calculateRideRouteAsyn(query);
            } else if(text.equals("walk")){
                RouteSearch.WalkRouteQuery query = new RouteSearch.WalkRouteQuery(fromAndTo, RouteSearch.WalkDefault);
                mRouteSearch.calculateWalkRouteAsyn(query);
            } else if(text.equals("car")){
                RouteSearch.DriveRouteQuery query = new RouteSearch.DriveRouteQuery(fromAndTo, RouteSearch.DrivingDefault, null,
                        null, "");
                mRouteSearch.calculateDriveRouteAsyn(query);
            } else if(text.equals("bus")){
                RouteSearch.BusRouteQuery query = new RouteSearch.BusRouteQuery(fromAndTo, RouteSearch.BusDefault,
                        "010", 0);// 第一个参数表示路径规划的起点和终点，第二个参数表示公交查询模式，第三个参数表示公交查询城市区号，第四个参数表示是否计算夜班车，0表示不计算
                mRouteSearch.calculateBusRouteAsyn(query);
            }
        }else if ("InjectData".equals(call.method)) {
            String text = (String) call.arguments;
            Log.e("amap", "InjectData");
            if(pointsArray.size() > 0){
                aMap.clear();
                pointsArray.clear();
            };
            initData(text);
        }else if ("setDestination".equals(call.method)) {
            if (call.arguments instanceof Integer) {
                int index = (Integer) call.arguments;
                Log.e("setDestination", "index: " + index);
                if (index >= 0 && index < pointsArray.size()) {
                    destination = pointsArray.get(index);
                    setCenter(destination);
                }
            } else if (call.arguments instanceof String) {
                String text = (String) call.arguments;
                Log.e("setDestination", "text: " + text);
                for(int i =0 ; i < pointsArray.size(); i++ ){
                    if(text.equals(pointsArray.get(i).getTitle())){
                        destination = pointsArray.get(i);
                        setCenter(destination);
                        break;
                    }
                }
            }
        }else if("changeCenter".equals(call.method)){
            String text = (String) call.arguments;
            Integer num = Integer.valueOf(text);
            int primitiveNum = num.intValue();
            setCenter(pointsArray.get(primitiveNum));
        } else if("getPoster".equals(call.method)){
            String text = (String) call.arguments;
            Log.e("amap", text);
        }else if ("clear".equals(call.method)) {
            aMap.clear();
            locationOnce();
        }else if ("notification".equals(call.method)) {
            String text = (String) call.arguments;
            try{
                JSONObject clientObj = new JSONObject(text);
                String points = clientObj.getString("destination");
                String wechat = clientObj.getString("wechat");
                builder.setContentText("微信号："+wechat+"；目的地："+ points);
                notificationManager.notify(channelId,1,builder.build());
            }catch(Exception e){

            }
        }else if ("naviget".equals(call.method) || "navigetGaode".equals(call.method)) {
            Log.e("amap", "naviget/navigetGaode called on NativeView");
            String mode = "";
            if (call.arguments instanceof String) {
                mode = (String) call.arguments;
            }
            int t = 0;
            if ("bus".equals(mode)) {
                t = 1;
            }
            Log.e("amap", "mode: " + mode + ", t: " + t + ", destination: " + (destination != null ? destination.getTitle() : "null"));
            navigetInGaodeApp(t);
        }else if ("navigetGoogle".equals(call.method)) {
            Log.e("amap", "navigetGoogle called on NativeView");
            String mode = "";
            if (call.arguments instanceof String) {
                mode = (String) call.arguments;
            }
            String googleMode = "driving";
            if ("bus".equals(mode)) {
                googleMode = "transit";
            }
            launchGoogleMapApp(googleMode);
        }else if ("callTexi".equals(call.method)) {
            callTexi();
        }else if ("openSysLocationPage".equals(call.method)) {
            String text = (String) call.arguments;
            Log.e("amap", "openSysLocationPage");
            if(activity1 != null){
                Log.e("check", "activity存在");
                activity1.startActivity(new Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS));
            }else {
                Log.e("check", "activity不存在");
            }
        }else if ("check".equals(call.method)) {
            String text = (String) call.arguments;
            Log.e("check", text);
            for (Marker marker:pointsArray){
                String title = marker.getTitle();
                if(title.equals(text)){
                    String snippet = marker.getSnippet();
                    String[] array = snippet.split("#");
                    int category = Integer.parseInt(array[0]);
                    boolean done = !Boolean.parseBoolean(array[1]);
                    String newSnippet = category + "#" + done;
                    Log.e("check", newSnippet);
                    LatLng latLng = marker.getPosition();
                    MarkerOptions markerOptions = new MarkerOptions();
                    if(category == 0){
                        if(!done){
                            markerOptions.icon(BitmapDescriptorFactory.fromResource(R.drawable.location));
                        } else {
                            markerOptions.icon(BitmapDescriptorFactory.fromResource(R.drawable.amap_through));
                        }
                    }
                    markerOptions.position(latLng);
                    markerOptions.title(text);
                    markerOptions.snippet(newSnippet);
                    Marker newMarker = aMap.addMarker(markerOptions);
                    int index = pointsArray.indexOf(marker);
                    if (index != -1) {
                        pointsArray.set(index, newMarker);
                    } else {
                        pointsArray.add(newMarker);
                    }
                    marker.destroy();
                    break;
                }
            }
        }
    }

    private void callTexi() {
        Context launchContext = activity1 != null ? activity1 : context1;
        try{
            Intent intent = new Intent("android.intent.action.VIEW", android.net.Uri.parse("amapuri://route/plan/?dlat="+ destination.getPosition().latitude + "&dlon=" + destination.getPosition().longitude + "&dev=0&t=" + 6));
            if (!(launchContext instanceof Activity)) {
                intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            }
            launchContext.startActivity(intent);
        } catch (Exception e){
            Toast.makeText(launchContext, "您尚未安装高德地图", Toast.LENGTH_SHORT).show();
            Uri uri = Uri.parse("market://details?id=com.autonavi.minimap");
            Intent intent = new Intent(Intent.ACTION_VIEW, uri);
            if (!(launchContext instanceof Activity)) {
                intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            }
            launchContext.startActivity(intent);
        }
        //goGaodeMap(context1, destination.getPosition().latitude, destination.getPosition().longitude, 6);
    }

    private void navigetInGaodeApp(int t) {
        if (destination == null) {
            Log.e("amap", "destination is null in navigetInGaodeApp!");
            Toast.makeText(context1, "未选中目的地", Toast.LENGTH_SHORT).show();
            return;
        }
        double latitude = 0.0;
        double longitude = 0.0;
        try {
            latitude = destination.getPosition().latitude;
            longitude = destination.getPosition().longitude;
        } catch (Exception e) {
            Log.e("amap", "Failed to get position from destination marker", e);
        }
        Context launchContext = activity1 != null ? activity1 : context1;
        try{
            Log.e("amap", "navigetInGaodeApp context is: " + launchContext + ", lat: " + latitude + ", lon: " + longitude + ", mode: " + t);
            Intent intent = new Intent("android.intent.action.VIEW", android.net.Uri.parse("amapuri://route/plan/?dlat="+ latitude + "&dlon=" + longitude + "&dev=0&t=" + t));
            if (!(launchContext instanceof Activity)) {
                intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            }
            launchContext.startActivity(intent);
        } catch (Exception e){
            Log.e("amap", "Failed to launch Gaode Map app", e);
            Toast.makeText(launchContext, "您尚未安装高德地图", Toast.LENGTH_SHORT).show();
            try {
                Uri uri = Uri.parse("market://details?id=com.autonavi.minimap");
                Intent intent = new Intent(Intent.ACTION_VIEW, uri);
                if (!(launchContext instanceof Activity)) {
                    intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                }
                launchContext.startActivity(intent);
            } catch (Exception storeException) {
                Log.e("amap", "Failed to launch Play Store link, falling back to Web browser", storeException);
                try {
                    Uri webUri = Uri.parse("https://uri.amap.com/marker?position=" + longitude + "," + latitude + "&name=" + Uri.encode(destination.getTitle()));
                    Intent webIntent = new Intent(Intent.ACTION_VIEW, webUri);
                    if (!(launchContext instanceof Activity)) {
                        webIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    }
                    launchContext.startActivity(webIntent);
                } catch (Exception webException) {
                    Log.e("amap", "Failed to launch Web browser fallback", webException);
                }
            }
        }
        //goGaodeMap(context1, destination.getPosition().latitude, destination.getPosition().longitude, t);
    }

    private void launchGoogleMapApp(String d) {
        if (destination == null) {
            Log.e("amap", "destination is null in launchGoogleMapApp!");
            Toast.makeText(context1, "未选中目的地", Toast.LENGTH_SHORT).show();
            return;
        }
        double lat = destination.getPosition().latitude;
        double lon = destination.getPosition().longitude;
        double startLat = 0.0;
        double startLon = 0.0;
        if (depart != null) {
            startLat = depart.getLatitude();
            startLon = depart.getLongitude();
        }
        
        Context launchContext = activity1 != null ? activity1 : context1;
        String url1 = "https://www.google.com/maps/dir/?api=1&origin=" + startLat + "%2C" + startLon + "&destination=" + lat + "%2C" + lon + "&travelmode=" + d;
        if (isInstallApk(launchContext, "com.google.android.apps.maps")) {
            try {
                Intent intent = new Intent("android.intent.action.VIEW", Uri.parse(url1));
                if (!(launchContext instanceof Activity)) {
                    intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                }
                intent.setPackage("com.google.android.apps.maps");
                launchContext.startActivity(intent);
            } catch (Exception e) {
                e.printStackTrace();
            }
        } else {
            Toast.makeText(launchContext, "您尚未安装谷歌地图！", Toast.LENGTH_SHORT).show();
            try {
                Uri uri = Uri.parse("market://details?id=com.google.android.apps.maps");
                Intent intent = new Intent(Intent.ACTION_VIEW, uri);
                if (!(launchContext instanceof Activity)) {
                    intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                }
                launchContext.startActivity(intent);
            } catch (Exception e) {
                try {
                    Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url1));
                    if (!(launchContext instanceof Activity)) {
                        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    }
                    launchContext.startActivity(intent);
                } catch (Exception webEx) {
                    webEx.printStackTrace();
                }
            }
        }
    }

    private void add(List<Polyline> Polylines1, List<Polyline> Polylines2){
        for (Polyline line : Polylines2) {
            Polylines1.add(line);
        }
    }

    private void remove(List<Polyline> Polylines, List<Marker> markers){
        if(PolyLines.size() > 0){
            for (Polyline line : PolyLines) {
                line.remove();
            }
            PolyLines.clear();
        }
        if(markers.size() > 0){
            for (Marker marker : markers) {
                marker.remove();
            }
            markers.clear();
        }
    }

    public static void goGaodeMap(Context context, double latitude, double longtitude, int cat) {
        if (isInstallApk(context, "com.autonavi.minimap")) {
            Intent intent = new Intent("android.intent.action.VIEW", android.net.Uri.parse("amapuri://route/plan/?dlat="+ latitude + "&dlon=" + longtitude + "&dev=0&t=" + cat));
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
        } else {
            Toast.makeText(context, "您尚未安装高德地图", Toast.LENGTH_SHORT).show();
            Uri uri = Uri.parse("market://details?id=com.autonavi.minimap");
            Intent intent = new Intent(Intent.ACTION_VIEW, uri);
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
        }
    }
    public static boolean isInstallApk(Context context, String pkgName) {
        List<PackageInfo> packages = context.getPackageManager().getInstalledPackages(0);
        for (int i = 0; i < packages.size(); i++) {
            PackageInfo packageInfo = packages.get(i);
            if (packageInfo.packageName.equals(pkgName)) {
                return true;
            } else {
                continue;
            }
        }
        return false;
    }
}