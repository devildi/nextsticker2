import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:nextsticker2/model/travel_model.dart';

class CommonUtils {
  static bool developmentMode = true;
  static const String _lanHost = '10.20.177.50:4000';
  static const String lanUrl = 'http://$_lanHost/';
  static const String wsLan = 'ws://$_lanHost';
  static Color randomColor() {
    List colors = [Colors.red[100], Colors.green[100], Colors.yellow[100], Colors.orange[100]];
    Random random = Random();
    return colors[random.nextInt(4)]!;
  }

  static Future<void> deleteLocalFilesAsync(List<String> localURLs, {bool hasVideo = false}) async {
    if(hasVideo){
      String pic = localURLs[0];
      String video = localURLs[1];
      try {
        if (await isFileExist(pic)) {
          final file = await getLocalFileForResource(pic);
          await file.delete();
          debugPrint('已删除本地文件: $pic');
        } else {
          debugPrint('本地文件不存在: $pic');
        }
      } catch (e) {
        debugPrint('删除本地文件时发生错误: $e');
      }
      try {
        if (await isFileExist(video, isImg: false)) {
          final file = await getLocalFileForResource(video, isImg: false);
          await file.delete();
          debugPrint('已删除本地文件: $video');
        } else {
          debugPrint('本地文件不存在: $video');
        }
      } catch (e) {
        debugPrint('删除本地文件时发生错误: $e');
      }
    } else {
      for (String localURL in localURLs) {
        try {
          if (await isFileExist(localURL)) {
            final file = await getLocalFileForResource(localURL);
            await file.delete();
            debugPrint('已删除本地文件: $localURL');
          } else {
            debugPrint('本地文件不存在: $localURL');
          }
        } catch (e) {
          debugPrint('删除本地文件时发生错误: $e');
        }
      }
    }
  }

  static void showSnackBar(BuildContext context, String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: backgroundColor ?? Colors.blue,
        content: Text(message, textAlign: TextAlign.center),
      ),
    );
  }

  static void show(BuildContext context, String message, {Duration? duration}) {
    final overlay = Overlay.of(context);
    final mediaQuery = MediaQuery.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) {
        // 计算键盘是否弹出
        final keyboardHeight = mediaQuery.viewInsets.bottom;
        final isKeyboardVisible = keyboardHeight > 0;
        return Positioned(
          bottom: isKeyboardVisible 
              ? keyboardHeight + 18  // 键盘上方20像素
              : 100,  // 默认位置
          left: 0,
          right: 0,
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                ),
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        );
      },
    );

    // 插入到Overlay
    overlay.insert(overlayEntry);

    // 延时移除
    Future.delayed(duration ?? const Duration(seconds: 2)).then((value) {
      overlayEntry.remove();
    });
  }

  // 获取本地文件路径（基于资源 ID）
  static Future<String> getLocalURLForResource(String resourceId, {bool isImg = true}) async {
    // 获取应用的本地缓存目录
    final dir = await getApplicationDocumentsDirectory();
    String filename = '';
    // 使用资源 ID 作为文件名
    if(isImg){
      filename = '$resourceId.jpeg'; 
    } else {
      filename = '$resourceId.mp4';
    }
   
    return p.join(dir.path, filename);  // 拼接文件路径
  }

  // 获取本地文件路径（基于资源 ID）
  static Future<File> getLocalFileForResource(String resourceId, {bool isImg = true}) async {
    // 获取应用的本地缓存目录
    String filename = '';
    final dir = await getApplicationDocumentsDirectory();
    // 使用资源 ID 作为文件名
    if(isImg){
      filename = '$resourceId.jpeg'; 
    } else {
      filename = '$resourceId.mp4';
    }
     // 你可以根据需要修改文件扩展名
    return File(p.join(dir.path, filename));  // 拼接文件路径
  }

  // 检查本地是否已存在该资源文件
  static Future<bool> isFileExist(String resourceId, {bool isImg = true}) async {
    final file = await getLocalFileForResource(resourceId, isImg: isImg);
    return await file.exists();  // 判断文件是否存在
  }

  static String removeBaseUrl(String url) {
    if (url.contains('/')) {
      return url.split('/').last; // Get the filename/key segment
    }
    return url;
  }

  static List<dynamic> tripItemAndIndex(TravelModel cloneTrip, nameOfScence) {
    DetailModel item = DetailModel();
    List index = [];
    for (int i = 0; i < cloneTrip.detail.length; i++) {
      if(cloneTrip.detail[i].dayList.isNotEmpty){
        for (int j = 0; j < cloneTrip.detail[i].dayList.length; j++) {
          if(cloneTrip.detail[i].dayList[j].nameOfScence == nameOfScence){
            item = cloneTrip.detail[i].dayList[j];
            index.add(i);
            index.add(j);
            break;
          }
        }
      }
    }
    return [item, index];
  }

  static void showTripOverviewDialog(BuildContext context, TravelModel? travelData, {VoidCallback? onDelete}) {
    if (travelData == null) {
      show(context, '暂无行程数据概览');
      return;
    }

    int totalDays = travelData.detail.length;
    int totalLocations = 0;
    int completedLocations = 0;
    int attractionsCount = 0;
    int hotelCount = 0;
    int foodCount = 0;

    for (var day in travelData.detail) {
      for (var point in day.dayList) {
        totalLocations++;
        if (point.done) {
          completedLocations++;
        }
        if (point.category == 0) {
          attractionsCount++;
        } else if (point.category == 1) {
          hotelCount++;
        } else if (point.category == 2) {
          foodCount++;
        }
      }
    }

    double progress = totalLocations > 0 ? (completedLocations / totalLocations) : 0.0;
    String completionPercentage = (progress * 100).toStringAsFixed(0);

    String coverUrl = travelData.cover;
    if (coverUrl.isEmpty) {
      for (var day in travelData.detail) {
        for (var point in day.dayList) {
          if (point.picURL.isNotEmpty) {
            coverUrl = point.picURL;
            break;
          }
        }
        if (coverUrl.isNotEmpty) break;
      }
    }
    bool hasCover = coverUrl.isNotEmpty;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20.0,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        Container(
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.blue.shade600,
                                Colors.indigo.shade800,
                              ],
                            ),
                          ),
                          child: hasCover
                              ? Image.network(
                                  coverUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container();
                                  },
                                )
                              : null,
                        ),
                        Container(
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.1),
                                Colors.black.withOpacity(0.6),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 16.0,
                          left: 16.0,
                          right: 16.0,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                travelData.tripName.isNotEmpty ? travelData.tripName : '我的旅行计划',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22.0,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(0, 1),
                                      blurRadius: 3.0,
                                      color: Colors.black45,
                                    )
                                  ]
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4.0),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    color: Colors.redAccent,
                                    size: 14.0,
                                  ),
                                  const SizedBox(width: 4.0),
                                  Expanded(
                                    child: Text(
                                      (travelData.city.isNotEmpty || travelData.country.isNotEmpty)
                                          ? '${travelData.city} · ${travelData.country}'
                                          : '暂无目的地信息',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 12.0,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '打卡进度',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.0,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                '$completedLocations / $totalLocations 已打卡 ($completionPercentage%)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.0,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8.0),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10.0),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8.0,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade500),
                            ),
                          ),
                          const SizedBox(height: 20.0),
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            childAspectRatio: 2.2,
                            mainAxisSpacing: 10.0,
                            crossAxisSpacing: 10.0,
                            children: [
                              _buildStatCard(
                                icon: Icons.calendar_today,
                                color: Colors.blue.shade500,
                                value: '$totalDays 天',
                                label: '旅行周期',
                              ),
                              _buildStatCard(
                                icon: Icons.map,
                                color: Colors.indigo.shade500,
                                value: '$totalLocations 个',
                                label: '计划点位',
                              ),
                              _buildStatCard(
                                icon: Icons.hotel,
                                color: Colors.orange.shade600,
                                value: '$hotelCount 处',
                                label: '住宿酒店',
                              ),
                              _buildStatCard(
                                icon: Icons.restaurant,
                                color: Colors.green.shade600,
                                value: '$foodCount 处',
                                label: '美食餐饮',
                              ),
                            ],
                          ),
                          const SizedBox(height: 16.0),
                          const Divider(height: 24.0),
                          const Text(
                            '行程安排明细',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15.0,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12.0),
                          if (totalLocations == 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                '暂无行程点位',
                                style: TextStyle(
                                  fontSize: 12.0,
                                  color: Colors.grey.shade500,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: travelData.detail.asMap().entries.map((dayEntry) {
                                int dayIndex = dayEntry.key;
                                var day = dayEntry.value;
                                if (day.dayList.isEmpty) return const SizedBox.shrink();
                                
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 26,
                                          height: 26,
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.blue.shade100,
                                              width: 1.0,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              'D${dayIndex + 1}',
                                              style: TextStyle(
                                                fontSize: 10.0,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue.shade700,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8.0),
                                        Text(
                                          '第 ${dayIndex + 1} 天',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.0,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 12.0),
                                      child: Container(
                                        padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            left: BorderSide(
                                              color: Colors.grey.shade200,
                                              width: 2.0,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          children: day.dayList.map((point) {
                                            IconData categoryIcon = Icons.place;
                                            Color iconColor = Colors.blue.shade500;
                                            if (point.category == 1) {
                                              categoryIcon = Icons.hotel;
                                              iconColor = Colors.orange.shade600;
                                            } else if (point.category == 2) {
                                              categoryIcon = Icons.restaurant;
                                              iconColor = Colors.green.shade600;
                                            }

                                            return Padding(
                                              padding: const EdgeInsets.only(left: 16.0, top: 6.0, bottom: 6.0),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    point.done ? Icons.check_circle : categoryIcon,
                                                    size: 14.0,
                                                    color: point.done ? Colors.green.shade500 : iconColor,
                                                  ),
                                                  const SizedBox(width: 8.0),
                                                  Expanded(
                                                    child: Text(
                                                      point.nameOfScence,
                                                      style: TextStyle(
                                                        fontSize: 12.0,
                                                        color: point.done ? Colors.grey.shade500 : Colors.black87,
                                                        decoration: point.done ? TextDecoration.lineThrough : null,
                                                        fontWeight: point.done ? FontWeight.normal : FontWeight.w500,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 16.0),
                          if (travelData.designer.isNotEmpty || travelData.tags.isNotEmpty) ...[
                            const Divider(height: 24.0),
                            if (travelData.designer.isNotEmpty) ...[
                              Row(
                                children: [
                                  Icon(Icons.edit, size: 14.0, color: Colors.grey.shade600),
                                  const SizedBox(width: 6.0),
                                  Text(
                                    '路线设计师: ',
                                    style: TextStyle(fontSize: 12.0, color: Colors.grey.shade600),
                                  ),
                                  Text(
                                    travelData.designer,
                                    style: const TextStyle(
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8.0),
                            ],
                            if (travelData.tags.isNotEmpty) ...[
                              Wrap(
                                spacing: 6.0,
                                runSpacing: 6.0,
                                children: travelData.tags
                                    .split(',')
                                    .where((t) => t.trim().isNotEmpty)
                                    .map((tag) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50.withOpacity(0.7),
                                            borderRadius: BorderRadius.circular(6.0),
                                            border: Border.all(color: Colors.blue.shade100, width: 0.5),
                                          ),
                                          child: Text(
                                            tag.trim(),
                                            style: TextStyle(
                                              fontSize: 10.0,
                                              color: Colors.blue.shade800,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ],
                          ],
                          const SizedBox(height: 24.0),
                          Row(
                            children: [
                              if (onDelete != null) ...[
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: Colors.red.shade400),
                                      foregroundColor: Colors.red.shade600,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12.0),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      onDelete();
                                    },
                                    child: const Text(
                                      '删除行程',
                                      style: TextStyle(
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12.0),
                              ],
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade600,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                                  ),
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text(
                                    '关闭概览',
                                    style: TextStyle(
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _buildStatCard({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: color.withOpacity(0.15),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6.0),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 16.0,
            ),
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.0,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.0,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}