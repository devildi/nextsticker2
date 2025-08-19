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

    public AMapLocationListener mLocationListener = new AMapLocationListener() {
        @Override
        public void onLocationChanged(AMapLocation aMapLocation) {
            if (aMapLocation != null && aMapLocation.getErrorCode() == 0) {
                Log.e("AmapErr","定位成功");
                //LatLng latLng = new LatLng(aMapLocation.getLatitude(), aMapLocation.getLongitude());
                depart = new LatLonPoint(aMapLocation.getLatitude(),aMapLocation.getLongitude());
                aMap.animateCamera(CameraUpdateFactory.newCameraPosition(new CameraPosition(new LatLng(aMapLocation.getLatitude(), aMapLocation.getLongitude()),16,30,0)));
            } else {
                String errText = "定位失败~~~~~~," + aMapLocation.getErrorCode()+ ": " + aMapLocation.getErrorInfo();
                Log.e("AmapErr",errText);
                methodChannel.invokeMethod("alert", true);
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
        methodChannel.setMethodCallHandler(this);
        context1 = context;
        activity1 = activity;
        authority();
        String points = creationParams.get("pointsString").toString();
        //显示地图
        if(mapView != null){
            mapView.onResume();
        }
        Log.e("map","地图初始化");
        AMapOptions mapOptions = new AMapOptions();
        if(depart != null){
            mapOptions.camera(new CameraPosition(new LatLng(depart.getLatitude(),depart.getLongitude()), 10f, 0, 0));
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
            locationOnce();
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
                JSONObject jsonObject = jsonArray.getJSONObject(i);
                String nameOfScence = jsonObject.getString("nameOfScence");
                double latitude = jsonObject.getDouble("latitude");
                double longitude = jsonObject.getDouble("longitude");
                int category = jsonObject.getInt("category");
                boolean done = jsonObject.getBoolean("done");

                LatLng latLng = new LatLng(latitude,longitude);
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
                Marker marker = aMap.addMarker(markerOptions);
                pointsArray.add(marker);
            }
        } catch(Exception e){

        }
    }

    private void authority() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (context1.checkSelfPermission(android.Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                //如果应用之前请求过此权限但用户拒绝了请求，此方法将返回 true。
                Log.e("quanxian","权限");
                if (ActivityCompat.shouldShowRequestPermissionRationale(activity1, android.Manifest.permission.ACCESS_COARSE_LOCATION)) {
                    //这里可以写个对话框之类的项向用户解释为什么要申请权限，并在对话框的确认键后续再次申请权限.它在用户选择"不再询问"的情况下返回false
                } else {
                    //申请权限，字符串数组内是一个或多个要申请的权限，1是申请权限结果的返回参数，在onRequestPermissionsResult可以得知申请结果
                    ActivityCompat.requestPermissions(activity1, new String[]{android.Manifest.permission.ACCESS_COARSE_LOCATION, Manifest.permission.ACCESS_FINE_LOCATION}, 1);
                }
            }
        }
    }

    private void setCenter(Marker marker){
        //Log.e("amap","居中");
        aMap.animateCamera(CameraUpdateFactory.newCameraPosition(new CameraPosition(marker.getPosition(),16,30,0)));
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
                methodChannel.invokeMethod("openBottomSheet", marker.getTitle());
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
            String text = (String) call.arguments;
            Log.e("setDestination", text);
            for(int i =0 ; i < pointsArray.size(); i++ ){
                if(text.equals(pointsArray.get(i).getTitle())){
                    destination = pointsArray.get(i);
                    setCenter(destination);
                    break;
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
        }else if ("naviget".equals(call.method)) {
            navigetInGaodeApp();
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
                    pointsArray.remove(marker);
                    pointsArray.add(newMarker);
                    marker.destroy();
                    break;
                }
            }
        }
    }

    private void callTexi() {
        try{
            Intent intent = new Intent("android.intent.action.VIEW", android.net.Uri.parse("amapuri://route/plan/?dlat="+ destination.getPosition().latitude + "&dlon=" + destination.getPosition().longitude + "&dev=0&t=" + 6));
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context1.startActivity(intent);
        } catch (Exception e){
            Toast.makeText(context1, "您尚未安装高德地图", Toast.LENGTH_SHORT).show();
            Uri uri = Uri.parse("market://details?id=com.autonavi.minimap");
            Intent intent = new Intent(Intent.ACTION_VIEW, uri);
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context1.startActivity(intent);
        }
        //goGaodeMap(context1, destination.getPosition().latitude, destination.getPosition().longitude, 6);
    }

    private void navigetInGaodeApp() {
        try{
            Intent intent = new Intent("android.intent.action.VIEW", android.net.Uri.parse("amapuri://route/plan/?dlat="+ destination.getPosition().latitude + "&dlon=" + destination.getPosition().longitude + "&dev=0&t=" + 0));
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context1.startActivity(intent);
        } catch (Exception e){
            Toast.makeText(context1, "您尚未安装高德地图", Toast.LENGTH_SHORT).show();
            Uri uri = Uri.parse("market://details?id=com.autonavi.minimap");
            Intent intent = new Intent(Intent.ACTION_VIEW, uri);
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context1.startActivity(intent);
        }
        //goGaodeMap(context1, destination.getPosition().latitude, destination.getPosition().longitude, 0);
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