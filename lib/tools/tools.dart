import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:nextsticker2/model/travel_model.dart';

class CommonUtils {
  static bool developmentMode = false;
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
          final file = await getLocalFileForResource(pic, isImg: false);
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
    const baseUrl = 'http://nextsticker.xyz/';
    if (url.startsWith(baseUrl)) {
      return url.substring(baseUrl.length);  // 去掉前缀部分
    }
    return url;  // 如果没有这个前缀，返回原始 URL
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
}