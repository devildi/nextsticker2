package com.example.nextsticker2;

//package overlay;

import java.util.ArrayList;
import java.util.List;

import com.amap.api.maps.AMap;
import com.amap.api.maps.model.BitmapDescriptor;
import com.amap.api.maps.model.LatLng;
import com.amap.api.maps.model.MarkerOptions;
import com.amap.api.maps.model.PolylineOptions;
import com.amap.api.services.core.LatLonPoint;
import com.amap.api.services.route.WalkPath;
import com.amap.api.services.route.WalkStep;

import android.content.Context;

/**
 * 步行路线图层类。在高德地图API里，如果要显示步行路线规划，可以用此类来创建步行路线图层。如不满足需求，也可以自己创建自定义的步行路线图层。
 * @since V2.1.0
 */
public class WalkRouteOverlay extends RouteOverlay {

    private PolylineOptions mPolylineOptions;

    private BitmapDescriptor walkStationDescriptor= null;

    private WalkPath walkPath;
    private double offsetMeters = 0.0;
    private List<LatLng> drawnPoints = new ArrayList<>();

    /**
     * 通过此构造函数创建步行路线图层。
     * @param context 当前activity。
     * @param amap 地图对象。
     * @param path 步行路线规划的一个方案。详见搜索服务模块的路径查询包（com.amap.api.services.route）中的类 <strong><a href="../../../../../../Search/com/amap/api/services/route/WalkStep.html" title="com.amap.api.services.route中的类">WalkStep</a></strong>。
     * @param start 起点。详见搜索服务模块的核心基础包（com.amap.api.services.core）中的类<strong><a href="../../../../../../Search/com/amap/api/services/core/LatLonPoint.html" title="com.amap.api.services.core中的类">LatLonPoint</a></strong>。
     * @param end 终点。详见搜索服务模块的核心基础包（com.amap.api.services.core）中的类<strong><a href="../../../../../../Search/com/amap/api/services/core/LatLonPoint.html" title="com.amap.api.services.core中的类">LatLonPoint</a></strong>。
     * @since V2.1.0
     */
    public WalkRouteOverlay(Context context, AMap amap, WalkPath path,
                            LatLonPoint start, LatLonPoint end) {
        super(context);
        this.mAMap = amap;
        this.walkPath = path;
        startPoint = AMapServicesUtil.convertToLatLng(start);
        endPoint = AMapServicesUtil.convertToLatLng(end);
    }

    public void setOffsetMeters(double offsetMeters) {
        this.offsetMeters = offsetMeters;
    }

    public List<LatLng> getDrawnPoints() {
        return drawnPoints;
    }

    /**
     * 添加步行路线到地图中。
     * @since V2.1.0
     */
    public void addToMap() {
        initPolylineOptions();
        try {
            List<LatLng> rawPoints = new ArrayList<>();
            List<WalkStep> walkPaths = walkPath.getSteps();
            for (int i = 0; i < walkPaths.size(); i++) {
                WalkStep walkStep = walkPaths.get(i);
                rawPoints.addAll(AMapServicesUtil.convertArrList(walkStep.getPolyline()));
            }

            if (offsetMeters > 0.0 && rawPoints.size() >= 2) {
                drawnPoints = offsetPolyline(rawPoints, offsetMeters);
            } else {
                drawnPoints = rawPoints;
            }

            mPolylineOptions.addAll(drawnPoints);
            showPolyline();
        } catch (Throwable e) {
            e.printStackTrace();
        }
    }

    public static List<LatLng> offsetPolyline(List<LatLng> rawPoints, double offsetMeters) {
        if (rawPoints == null || rawPoints.size() < 2) {
            return rawPoints;
        }

        // 去除连续重复或距离过近的点
        List<LatLng> points = new ArrayList<>();
        points.add(rawPoints.get(0));
        for (int i = 1; i < rawPoints.size(); i++) {
            LatLng pPrev = points.get(points.size() - 1);
            LatLng pCurr = rawPoints.get(i);
            double dLat = Math.abs(pCurr.latitude - pPrev.latitude);
            double dLon = Math.abs(pCurr.longitude - pPrev.longitude);
            if (dLat > 1e-7 || dLon > 1e-7) {
                points.add(pCurr);
            }
        }
        if (points.size() < 2) {
            return rawPoints;
        }

        int n = points.size();
        double[] segNx = new double[n - 1];
        double[] segNy = new double[n - 1];
        double[] cumDist = new double[n];

        for (int i = 0; i < n - 1; i++) {
            LatLng p1 = points.get(i);
            LatLng p2 = points.get(i + 1);

            double latMid = (p1.latitude + p2.latitude) / 2.0 * Math.PI / 180.0;
            double mLat = 111320.0;
            double mLon = 111320.0 * Math.cos(latMid);

            double dx = (p2.longitude - p1.longitude) * mLon;
            double dy = (p2.latitude - p1.latitude) * mLat;
            double len = Math.sqrt(dx * dx + dy * dy);
            if (len < 1e-6) len = 1e-6;

            cumDist[i + 1] = cumDist[i] + len;

            // 前进方向单位切向量: (dx / len, dy / len)
            double ux = dx / len;
            double uy = dy / len;

            // 右手法向量 (向右侧偏移): (uy, -ux)
            segNx[i] = uy;
            segNy[i] = -ux;
        }

        double totalDist = cumDist[n - 1];
        // 起点与终点前 15 米平滑过渡到 0，保证折线无缝对齐起始 Marker
        double rampDist = Math.min(15.0, totalDist / 3.0);

        List<LatLng> result = new ArrayList<>(n);
        for (int i = 0; i < n; i++) {
            double vx, vy;
            if (i == 0) {
                vx = segNx[0];
                vy = segNy[0];
            } else if (i == n - 1) {
                vx = segNx[n - 2];
                vy = segNy[n - 2];
            } else {
                vx = (segNx[i - 1] + segNx[i]) / 2.0;
                vy = (segNy[i - 1] + segNy[i]) / 2.0;
                double vLen = Math.sqrt(vx * vx + vy * vy);
                if (vLen < 1e-6) {
                    vx = segNx[i];
                    vy = segNy[i];
                } else {
                    vx /= vLen;
                    vy /= vLen;
                }
            }

            double dStart = cumDist[i];
            double dEnd = totalDist - cumDist[i];
            double ramp = 1.0;
            if (rampDist > 0) {
                if (dStart < rampDist) ramp = Math.min(ramp, dStart / rampDist);
                if (dEnd < rampDist) ramp = Math.min(ramp, dEnd / rampDist);
            }

            double currentOffset = offsetMeters * ramp;
            double latRad = points.get(i).latitude * Math.PI / 180.0;
            double mLat = 111320.0;
            double mLon = 111320.0 * Math.cos(latRad);

            double shiftX = currentOffset * vx;
            double shiftY = currentOffset * vy;

            double newLat = points.get(i).latitude + shiftY / mLat;
            double newLon = points.get(i).longitude + shiftX / mLon;

            result.add(new LatLng(newLat, newLon));
        }

        return result;
    }

    /**
     * 检查这一步的最后一点和下一步的起始点之间是否存在空隙
     */
    private void checkDistanceToNextStep(WalkStep walkStep,
                                         WalkStep walkStep1) {
        LatLonPoint lastPoint = getLastWalkPoint(walkStep);
        LatLonPoint nextFirstPoint = getFirstWalkPoint(walkStep1);
        if (!(lastPoint.equals(nextFirstPoint))) {
            addWalkPolyLine(lastPoint, nextFirstPoint);
        }
    }

    /**
     * @param walkStep
     * @return
     */
    private LatLonPoint getLastWalkPoint(WalkStep walkStep) {
        return walkStep.getPolyline().get(walkStep.getPolyline().size() - 1);
    }

    /**
     * @param walkStep
     * @return
     */
    private LatLonPoint getFirstWalkPoint(WalkStep walkStep) {
        return walkStep.getPolyline().get(0);
    }


    private void addWalkPolyLine(LatLonPoint pointFrom, LatLonPoint pointTo) {
        addWalkPolyLine(AMapServicesUtil.convertToLatLng(pointFrom), AMapServicesUtil.convertToLatLng(pointTo));
    }

    private void addWalkPolyLine(LatLng latLngFrom, LatLng latLngTo) {
        mPolylineOptions.add(latLngFrom, latLngTo);
    }

    /**
     * @param walkStep
     */
    private void addWalkPolyLines(WalkStep walkStep) {
        mPolylineOptions.addAll(AMapServicesUtil.convertArrList(walkStep.getPolyline()));
    }

    /**
     * @param walkStep
     * @param position
     */
    private void addWalkStationMarkers(WalkStep walkStep, LatLng position) {
        addStationMarker(new MarkerOptions()
                .position(position)
                .title("\u65B9\u5411:" + walkStep.getAction()
                        + "\n\u9053\u8DEF:" + walkStep.getRoad())
                .snippet(walkStep.getInstruction()).visible(nodeIconVisible)
                .anchor(0.5f, 0.5f).icon(walkStationDescriptor));
    }

    private int customColor = 0;

    public void setCustomColor(int color) {
        this.customColor = color;
    }

    /**
     * 初始化线段属性
     */
    private void initPolylineOptions() {

        if(walkStationDescriptor == null) {
            walkStationDescriptor = getWalkBitmapDescriptor();
        }

        mPolylineOptions = null;

        mPolylineOptions = new PolylineOptions();
        mPolylineOptions.color(customColor != 0 ? customColor : getWalkColor()).width(getRouteWidth());
    }


    private void showPolyline() {
        addPolyLine(mPolylineOptions);
    }
}
