import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:io';

class CommonUtils {
  static Color randomColor() {
    List colors = [Colors.red[100], Colors.green[100], Colors.yellow[100], Colors.orange[100]];
    Random random = Random();
    return colors[random.nextInt(4)]!;
  }

  static Future<void> deleteLocalFilesAsync(List<String> localURLs) async {
    for (String localURL in localURLs) {
      try {
        final file = File(localURL);
        if (await file.exists()) {
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
}