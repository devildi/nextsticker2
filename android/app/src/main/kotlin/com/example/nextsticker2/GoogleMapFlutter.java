package com.example.nextsticker2;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
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
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.platform.PlatformView;
import okhttp3.Call;
import okhttp3.Callback;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;

import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.maps.CameraUpdateFactory;
import com.google.android.gms.maps.GoogleMap;
import com.google.android.gms.maps.GoogleMapOptions;
import com.google.android.gms.maps.LocationSource;
import com.google.android.gms.maps.MapView;
import com.google.android.gms.maps.MapsInitializer;
import com.google.android.gms.maps.OnMapReadyCallback;
import com.google.android.gms.maps.OnMapsSdkInitializedCallback;
import com.google.android.gms.maps.UiSettings;
import com.google.android.gms.maps.model.BitmapDescriptorFactory;
import com.google.android.gms.maps.model.CameraPosition;
import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.LatLngBounds;
import com.google.android.gms.maps.model.Marker;
import com.google.android.gms.maps.model.MarkerOptions;
import com.google.android.gms.maps.model.Polyline;
import com.google.android.gms.maps.model.PolylineOptions;
import com.google.android.gms.maps.model.StampStyle;
import com.google.android.gms.maps.model.StrokeStyle;
import com.google.android.gms.maps.model.StyleSpan;
import com.google.android.gms.maps.model.TextureStyle;
import com.google.android.gms.tasks.CancellationToken;
import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.OnSuccessListener;
import com.google.android.gms.tasks.Task;

import org.jetbrains.annotations.NotNull;
import org.json.JSONArray;
import org.json.JSONObject;

class GoogleMapFlutter<MapActivity, FusedLocationProviderClient> extends AppCompatActivity implements OnMapsSdkInitializedCallback,PlatformView, GoogleMap.OnMapClickListener, OnMapReadyCallback, GoogleMap.OnMarkerClickListener, MethodChannel.MethodCallHandler, ActivityCompat.OnRequestPermissionsResultCallback, GoogleMap.OnMyLocationClickListener, LocationSource.OnLocationChangedListener {
    MapView mapView;
    Context context1 = null;
    Activity activity1 = null;
    MethodChannel methodChannel;
    private UiSettings mUiSettings;
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
    String channelId = "test";
    String channelName = "测试通知";
    NotificationManager notificationManager;
    Notification.Builder builder;
    NotificationChannel channel;

    GoogleMapFlutter( Context context, BinaryMessenger messenger, int id, Map<String, Object> creationParams, Activity activity) {
        methodChannel = new MethodChannel(messenger, "gaode_native_channel");
        methodChannel.setMethodCallHandler(this);
        MapsInitializer.initialize(context, MapsInitializer.Renderer.LATEST, this);
        context1 = context;
        activity1 = activity;
        authority();
        locationOnce(activity1);
        points = creationParams.get("pointsString").toString();
        if (mapView != null) {
            mapView.onResume();
        }
        GoogleMapOptions options = new GoogleMapOptions();
        options.compassEnabled(true).rotateGesturesEnabled(true).tiltGesturesEnabled(true);
        mapView = new MapView(context, options);
        mapView.onCreate(new Bundle());
        mapView.getMapAsync(this);

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
    public void onMapReady(GoogleMap googleMap) {
        Log.e("AmapErr", "显示地图");
        map = googleMap;
        if(depart != null){
            googleMap.moveCamera(CameraUpdateFactory.newLatLng(new LatLng(depart.latitude, depart.longitude)));
        } else {
            googleMap.moveCamera(CameraUpdateFactory.newLatLng(new LatLng(41.80, 123.46)));
        }
        googleMap.moveCamera(CameraUpdateFactory.zoomTo(15));
        initData(points);
        //googleMap.setTrafficEnabled(true);
        googleMap.setOnMarkerClickListener(this);
        googleMap.setMyLocationEnabled(true);
        googleMap.setOnMyLocationClickListener(this);

        mUiSettings = googleMap.getUiSettings();
        mUiSettings.setCompassEnabled(true);
        mUiSettings.setMyLocationButtonEnabled(false);
        mUiSettings.setMapToolbarEnabled(false);
    }

    private void initData(String jsonData) {
        Log.e("map", "开始渲染点坐标");
        try {
            JSONArray jsonArray = new JSONArray(jsonData);
            for (int i = 0; i < jsonArray.length(); i++) {
                JSONObject jsonObject = jsonArray.getJSONObject(i);
                String nameOfScence = jsonObject.getString("nameOfScence");
                double latitude = jsonObject.getDouble("latitude");
                double longitude = jsonObject.getDouble("longitude");
                int category = jsonObject.getInt("category");
                boolean done = jsonObject.getBoolean("done");

                LatLng latLng = new LatLng(latitude, longitude);
                MarkerOptions markerOptions = new MarkerOptions();
                if (category == 0) {
                    if (!done) {
                        //markerOptions.icon(BitmapDescriptorFactory.fromResource(R.drawable.location));
                    } else {
                        markerOptions.icon(BitmapDescriptorFactory.fromResource(R.drawable.amap_through));
                    }
                } else if (category == 1) {
                    markerOptions.icon(BitmapDescriptorFactory.fromResource(R.drawable.hotel));
                } else if (category == 2) {
                    markerOptions.icon(BitmapDescriptorFactory.fromResource(R.drawable.food));
                }
                markerOptions.position(latLng);
                markerOptions.title(nameOfScence);
                markerOptions.snippet(Integer.toString(category) + "#" + Boolean.toString(done));
                Marker marker = map.addMarker(markerOptions);
                pointsArray.add(marker);
            }
        } catch (Exception e) {

        }
    }

    private void add(List<Polyline> Polylines1, List<Polyline> Polylines2) {
        for (Polyline line : Polylines2) {
            Polylines1.add(line);
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
            locationOnce(activity1);
        } else if ("genRoute".equals(call.method)) {
            String text = (String) call.arguments;
            try {
                genRoute(text);
            } catch (IOException e) {
                e.printStackTrace();
            }
        } else if("changeCenter".equals(call.method)){
            String text = (String) call.arguments;
            Integer num = Integer.valueOf(text);
            int primitiveNum = num.intValue();
            setCenter(pointsArray.get(primitiveNum));
        } else if ("InjectData".equals(call.method)) {
            String text = (String) call.arguments;
            Log.e("amap", "InjectData");
            if (pointsArray.size() > 0) {
                map.clear();
                pointsArray.clear();
            };
            initData(text);
        } else if ("setDestination".equals(call.method)) {
            String text = (String) call.arguments;
            Log.e("setDestination", text);
            for (int i = 0; i < pointsArray.size(); i++) {
                if (text.equals(pointsArray.get(i).getTitle())) {
                    destination = pointsArray.get(i);
                    setCenter(destination);
                    break;
                }
            }
        } else if ("getPoster".equals(call.method)) {

        } else if ("clear".equals(call.method)) {
            map.clear();
        } else if ("notification".equals(call.method)) {
            String text = (String) call.arguments;
            try{
                JSONObject clientObj = new JSONObject(text);
                String points = clientObj.getString("destination");
                String wechat = clientObj.getString("wechat");
                builder.setContentText("微信号："+wechat+"；目的地："+ points);
                notificationManager.notify(channelId,1,builder.build());
            }catch(Exception e){

            }
        } else if ("naviget".equals(call.method)) {
            goGoogleMap(context1, depart, destination, "driving");
        } else if ("callTexi".equals(call.method)) {
            goGoogleMap(context1, depart, destination, "car");
        } else if ("toGoogleMapApp".equals(call.method)) {
            String text = (String) call.arguments;
            goGoogleMap(context1, depart, destination, getMode(text));
        }else if ("openSysLocationPage".equals(call.method)) {
            String text = (String) call.arguments;
            Log.e("amap", "openSysLocationPage");
            if (activity1 != null) {
                Log.e("check", "activity存在");
                activity1.startActivity(new Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS));
            } else {
                Log.e("check", "activity不存在");
            }
        } else if ("check".equals(call.method)) {
            String text = (String) call.arguments;
            Log.e("check", text);
            for (Marker marker : pointsArray) {
                String title = marker.getTitle();
                if (title.equals(text)) {
                    String snippet = marker.getSnippet();
                    String[] array = snippet.split("#");
                    int category = Integer.parseInt(array[0]);
                    boolean done = !Boolean.parseBoolean(array[1]);
                    String newSnippet = category + "#" + done;
                    Log.e("check", newSnippet);
                    LatLng latLng = marker.getPosition();
                    MarkerOptions markerOptions = new MarkerOptions();
                    if (category == 0) {
                        if (!done) {
                            //markerOptions.icon(BitmapDescriptorFactory.fromResource(R.drawable.location));
                        } else {
                            markerOptions.icon(BitmapDescriptorFactory.fromResource(R.drawable.amap_through));
                        }
                    }
                    markerOptions.position(latLng);
                    markerOptions.title(text);
                    markerOptions.snippet(newSnippet);
                    Marker newMarker = map.addMarker(markerOptions);
                    pointsArray.remove(marker);
                    pointsArray.add(newMarker);
                    marker.remove();
                    break;
                }
            }
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

    public static void goGoogleMap(Context context, LatLng depart ,Marker destination, String d) {
        //String url1 = "https://www.google.com/maps/dir/?api=1&origin=34.695044%2C135.50504&destination="+destination.getPosition().latitude+"%2C"+destination.getPosition().longitude+"&travelmode="+d;
        //34.695044,135.50504
        //String url = "google.navigation:q=" + destination.getPosition().latitude+","+ destination.getPosition().longitude + "&mode="+ d;
        String url1 = "https://www.google.com/maps/dir/?api=1&origin="+depart.latitude+"%2C"+depart.longitude+"&destination="+destination.getPosition().latitude+"%2C"+destination.getPosition().longitude+"&travelmode="+d;
        if (!isInstallApk(context, "com.google.android.apps.maps")) {
            Intent intent = new Intent("android.intent.action.VIEW",
                    android.net.Uri.parse(url1));
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            intent.setPackage("com.google.android.apps.maps");
            context.startActivity(intent);
        } else {
            Toast.makeText(context, "您尚未安装谷歌地图！", Toast.LENGTH_SHORT).show();
            Uri uri = Uri.parse("market://details?id=com.google.android.apps.maps");
            Intent intent = new Intent(Intent.ACTION_VIEW, uri);
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
        }
    }

    @Override
    public void onMyLocationClick(@NotNull Location location) {
        Log.e("点击","自己");
        //Toast.makeText(context1, "Current location:\n" + location, Toast.LENGTH_LONG).show();
        remove(polyLines, trans, polyLinesArray, markerOptionsArray);
        map.animateCamera(CameraUpdateFactory.newLatLngZoom(new LatLng(location.getLatitude(), location.getLongitude()), 15));
        depart = new LatLng(location.getLatitude(),location.getLongitude());
        methodChannel.invokeMethod("clearInfor",null);
    }

    @Override
    public boolean onMarkerClick(@NotNull Marker marker) {
        Log.e("点击","图标");
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
            remove(polyLines, trans, polyLinesArray, markerOptionsArray);
            //map.animateCamera(CameraUpdateFactory.newCameraPosition(new CameraPosition(new LatLng(depart.getLatitude(), depart.getLongitude()), 16,30,0)));
            methodChannel.invokeMethod("clearInfor",null);
        }
        return true;
    }

    @Override
    public void onLocationChanged(@NotNull Location location) {
        if(location.getLongitude() == 0.0 && location.getLongitude() == 0.0){
            Log.e("onMyLocationChange","请获取定位权限");
        } else {
            Log.e("onMyLocationChange","位置更改");
            depart = new LatLng(location.getLatitude(),location.getLongitude());
        }
    }

    private  String getURL(String type, LatLng depart, Marker destination){

        String mode = null;
        if(type.equals("bike")) {
            mode = "bicycling";
        } else if(type.equals("walk")){
            mode = "walking";
        } else if(type.equals("car")){
            mode = "driving";
        } else if(type.equals("bus")){
            mode = "transit";
        }
        //135.50504,34.695044
        //return "https://maps.googleapis.com/maps/api/directions/json?origin=34.695044,135.50504&destination="+destination.getPosition().latitude +","+destination.getPosition().longitude+"&key=AIzaSyB5LS2bbGE_Iw1e7Dc3_al7glDliILip_c&mode=" + mode;
        return "https://maps.googleapis.com/maps/api/directions/json?origin="+depart.latitude+","+depart.longitude+"&destination="+destination.getPosition().latitude +","+destination.getPosition().longitude+"&key=AIzaSyB5LS2bbGE_Iw1e7Dc3_al7glDliILip_c&mode=" + mode;
    }

    private  String getMode(String type){

        String mode = null;
        if(type.equals("bike")) {
            mode = "bicycling";
        } else if(type.equals("walk")){
            mode = "walking";
        } else if(type.equals("car")){
            mode = "driving";
        } else if(type.equals("bus")){
            mode = "transit";
        }
        return mode;
    }

    private  int color(String type){
        if(type.equals("walk")){
            return Color.BLUE;
        } else {
            return Color.GREEN;
        }
    }

    private void genRoute(String text) throws IOException {
        remove(polyLines, trans, polyLinesArray, markerOptionsArray);
        methodChannel.invokeMethod("isLoadingRoute",true);
        String Url = getURL(text, depart, destination);
        Log.e("router",text);
        //1.拿到okHttpClient对象,可以设置连接超时等
        OkHttpClient okHttpClient=new OkHttpClient();
        //2.构造Request请求对象，可以增加头addHeader等
        Request.Builder builder = new Request.Builder();
        //url()中可以放入网址
        Request request = builder.
                get().
                url(Url)
                .build();
        //3.将Request封装为Call
        Call call = okHttpClient.newCall(request);
        //4.执行call
        //方法一Response response=call.execute();//汇抛出IO异常，同步方法
        //方法二,异步方法，放到队列中,处于子线程中，无法更新UI
        call.enqueue(new Callback() {
            //请求时失败时调用
            @Override
            public void onFailure(Call call, IOException e) {
                //methodChannel.invokeMethod("aMapSearchRequestError","系统错误，请稍后再试！");
            }
            //请求成功时调用
            @Override
            public void onResponse(Call call, Response response) throws IOException {
                //处于子线程中，能够进行大文件下载，但是无法更新UI
                String responseData = response.body().string();

                LatLngBounds b = null;
                int result1 [] = new int[2];
                try{
                    JSONObject jsonObject = new JSONObject(responseData);
                    String status = jsonObject.getString("status");
                    if(status.equals("OK")) {
                        String routes = jsonObject.getString("routes");//路线详情
                        JSONArray routesArray = new JSONArray(routes);
                        JSONObject route = routesArray.getJSONObject(0);

                        String bounds = route.getString("bounds");
                        JSONObject boundsObj = new JSONObject(bounds);
                        String NEString = boundsObj.getString("northeast");

                        JSONObject NEObj = new JSONObject(NEString);
                        double NElat = NEObj.getDouble("lat");
                        double NElng = NEObj.getDouble("lng");
                        String SWString = boundsObj.getString("southwest");
                        JSONObject SWObj = new JSONObject(SWString);
                        double SWlat = SWObj.getDouble("lat");
                        double SWlng = SWObj.getDouble("lng");
                        b = new LatLngBounds(
                                new LatLng(SWlat, SWlng), // SW bounds
                                new LatLng(NElat, NElng)  // NE bounds
                        );
                        if(!text.equals("bus")){
                            String overview_polyline = route.getString("overview_polyline");
                            JSONObject overview_polylineObj = new JSONObject(overview_polyline);
                            String points = overview_polylineObj.getString("points");
                            List <LatLng> decoded = decodePoly(points);
                            StampStyle stampStyle = TextureStyle.newBuilder(BitmapDescriptorFactory.fromResource(R.drawable.custtexture)).build();
                            StyleSpan span = new StyleSpan(StrokeStyle.colorBuilder(Color.RED).stamp(stampStyle).build());
                            PolylineOptions polylineOptions = new PolylineOptions().addAll(decoded).addSpan(span).color(color(text)).width(20).geodesic(true);
                            polyLinesArray.add(polylineOptions);
                        }

                        String legs = route.getString("legs");
                        JSONArray legsArray = new JSONArray(legs);
                        JSONObject leg = legsArray.getJSONObject(0);
                        if(text.equals("bus")){
                            String steps = leg.getString("steps");
                            JSONArray stepsArray = new JSONArray(steps);
                            for (int i=0; i < stepsArray.length(); i++)    {
                                JSONObject item = stepsArray.getJSONObject(i);
                                String travel_mode = item.getString("travel_mode");

                                String polylineString = item.getString("polyline");
                                JSONObject polylineObj = new JSONObject(polylineString);
                                String points = polylineObj.getString("points");
                                List <LatLng> decoded = decodePoly(points);
                                PolylineOptions polylineOptions = null;
                                if(travel_mode.equals("WALKING")){
                                    Log.e("mapClick", String.valueOf(i));
                                    polylineOptions = new PolylineOptions().addAll(decoded).color(Color.BLUE).width(20).geodesic(true);
                                    polyLinesArray.add(polylineOptions);
                                    Log.e("mapClick", "添加ploline到walking");
                                } else {
                                    polylineOptions = new PolylineOptions().addAll(decoded).color(Color.GREEN).width(20).geodesic(true);
                                    polyLinesArray.add(polylineOptions);

                                    String transit_details = item.getString("transit_details");
                                    JSONObject transitDetailsObj = new JSONObject(transit_details);

                                    String departure_stop = transitDetailsObj.getString("departure_stop");
                                    JSONObject departureStopObl = new JSONObject(departure_stop);
                                    String departureStopName = departureStopObl.getString("name");
                                    String locationString = departureStopObl.getString("location");
                                    JSONObject location = new JSONObject(locationString);
                                    double departurelat = location.getDouble("lat");
                                    double departurelng = location.getDouble("lng");

                                    String arrival_stop = transitDetailsObj.getString("arrival_stop");
                                    JSONObject arrivalStopObl = new JSONObject(arrival_stop);
                                    String arrivalStopName = departureStopObl.getString("name");
                                    String arrivalLocationString = arrivalStopObl.getString("location");
                                    JSONObject arrivalLocation = new JSONObject(arrivalLocationString);
                                    double arrivallat = arrivalLocation.getDouble("lat");
                                    double arrivallng = arrivalLocation.getDouble("lng");

                                    String lineString = transitDetailsObj.getString("line");
                                    JSONObject line = new JSONObject(lineString);
                                    String short_name = line.getString("short_name");

                                    String vehicleString = line.getString("vehicle");
                                    JSONObject vehicle = new JSONObject(vehicleString);
                                    String type = vehicle.getString("type");

                                    MarkerOptions departureMarkerOptions = new MarkerOptions();
                                    LatLng departurelatLng = new LatLng(departurelat, departurelng);
                                    departureMarkerOptions.icon(BitmapDescriptorFactory.fromResource(R.drawable.transfer));
                                    departureMarkerOptions.position(departurelatLng);
                                    departureMarkerOptions.title("上车："+ departureStopName);
                                    departureMarkerOptions.snippet(type+ "|" + short_name);
                                    markerOptionsArray.add(departureMarkerOptions);

                                    MarkerOptions arrivalMarkerOptions = new MarkerOptions();
                                    LatLng arrivallatLng = new LatLng(arrivallat, arrivallng);
                                    arrivalMarkerOptions.icon(BitmapDescriptorFactory.fromResource(R.drawable.transfer));
                                    arrivalMarkerOptions.position(arrivallatLng);
                                    arrivalMarkerOptions.title("下车："+ arrivalStopName);
                                    arrivalMarkerOptions.snippet(type+ "|" + short_name);
                                    markerOptionsArray.add(arrivalMarkerOptions);
                                }
                            }
                        }

                        String distance = leg.getString("distance");
                        JSONObject distanceObj = new JSONObject(distance);
                        result1[0] = distanceObj.getInt("value");

                        String duration = leg.getString("duration");
                        JSONObject durationObj = new JSONObject(duration);
                        result1[1] = durationObj.getInt("value");

                    }
                } catch(Exception e){
                    Log.e("mapClick", String.valueOf(e));
                }
                //InputStream is=response.body().byteStream();
                // 执行IO操作时，能够下载很大的文件，并且不会占用很大内存
                /**
                 * runOnUiThread方法切换到主线程中，或者用handler机制也可以
                 */
                LatLngBounds finalB = b;
                runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        // 更新ui
                        if(finalB != null){
                            for (int i =0 ; i < polyLinesArray.size(); i++){
                                Polyline line = map.addPolyline(polyLinesArray.get(i));
                                polyLines.add(line);
                            }
                            for (int i =0 ; i < markerOptionsArray.size(); i++){
                                Marker marker = map.addMarker(markerOptionsArray.get(i));
                                trans.add(marker);
                            }
                            methodChannel.invokeMethod("stopLoadingRoute",true);
                            map.moveCamera(CameraUpdateFactory.newLatLngBounds(finalB, 120));
                            methodChannel.invokeMethod("openSnackBar",result1);
                        } else {
                            methodChannel.invokeMethod("aMapSearchRequestError","");
                        }
                    }
                });
            }
        });
    }

    private void remove(List<Polyline> polylines, List<Marker> markers, List<PolylineOptions> polyLinesArray, List<MarkerOptions> markerOptionsArray){
        if(polylines.size() > 0){
            for (Polyline line : polylines) {
                line.remove();
            }
            polylines.clear();
        }
        if(markers.size() > 0){
            for (Marker marker : markers) {
                marker.remove();
            }
            markers.clear();
        }
        if(polyLinesArray.size() > 0){
            polyLinesArray.clear();
        }
        if(markerOptionsArray.size() >0){
            markerOptionsArray.clear();
        }
    }

    @Override
    public void onMapClick(@NotNull LatLng latLng) {
        Log.e("mapClick", "mapClick");
        if(trans.size() > 0){
            for(Marker marker:trans){
                if(marker.isInfoWindowShown()){
                    marker.hideInfoWindow();
                }
            }
        }
    }

    private List<LatLng> decodePoly(String encoded) {

        List<LatLng> poly = new ArrayList<>();
        int index = 0, len = encoded.length();
        int lat = 0, lng = 0;

        while (index < len) {
            int b, shift = 0, result = 0;
            do {
                b = encoded.charAt(index++) - 63;
                result |= (b & 0x1f) << shift;
                shift += 5;
            } while (b >= 0x20);
            int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
            lat += dlat;

            shift = 0;
            result = 0;
            do {
                b = encoded.charAt(index++) - 63;
                result |= (b & 0x1f) << shift;
                shift += 5;
            } while (b >= 0x20);
            int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
            lng += dlng;

            LatLng p = new LatLng((((double) lat / 1E5)),
                    (((double) lng / 1E5)));
            poly.add(p);
        }
        return poly;
    }

    @Override
    public void onMapsSdkInitialized(@NotNull MapsInitializer.Renderer renderer) {
        switch (renderer) {
            case LATEST:
                Log.d("MapsDemo", "The latest version of the renderer is used.");
                break;
            case LEGACY:
                Log.d("MapsDemo", "The legacy version of the renderer is used.");
                break;
        }
    }

    @SuppressLint("MissingPermission")
    public void locationOnce(Activity activity){
        LocationServices.getFusedLocationProviderClient(activity).getLastLocation()
            .addOnSuccessListener(activity, new OnSuccessListener<Location>() {
                @Override
                public void onSuccess(Location location) {
                    // Got last known location. In some rare situations this can be null.
                    if (location != null) {
                        // Logic to handle location object
                        Log.e("AmapErr", String.valueOf(location));
                        if(map != null){
                            map.animateCamera(CameraUpdateFactory.newLatLngZoom(new LatLng(location.getLatitude(), location.getLongitude()), 15));
                        }
                        depart = new LatLng(location.getLatitude(),location.getLongitude());
                    }
                }
            });
    }
}