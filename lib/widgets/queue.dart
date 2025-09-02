import 'dart:async';
import 'package:flutter/foundation.dart';
/// 高级异步任务队列
class AsyncQueue {
  final int concurrency; // 并发数
  final int maxRetries;  // 每个任务最大重试次数
  final _taskQueue = <_QueueTask>[];
  int _runningCount = 0;

  // 状态回调
  void Function(int index)? onTaskStart;
  void Function(int index)? onTaskDone;
  void Function(int index, dynamic error)? onTaskError;
  VoidCallback? onQueueEmpty;

  AsyncQueue({this.concurrency = 3, this.maxRetries = 3});

  /// 添加任务到队列
  void addTask(String tripId, Future<void> Function() task) {
    _taskQueue.add(_QueueTask(tripId, task, maxRetries));
    _tryRunNext();
  }

  /// 尝试执行任务
  void _tryRunNext() {
    while (_runningCount < concurrency && _taskQueue.isNotEmpty) {
      final task = _taskQueue.removeAt(0);
      final index = task.id;
      _runningCount++;

      onTaskStart?.call(index);

      task.run().then((_) {
        onTaskDone?.call(index);
      }).catchError((e) {
        onTaskError?.call(index, e);
        // 失败且还有重试次数
        if (task.retries > 0) {
          task.retries--;
          _taskQueue.add(task);
        }
      }).whenComplete(() {
        _runningCount--;
        if (_taskQueue.isEmpty && _runningCount == 0) {
          onQueueEmpty?.call();
        } else {
          _tryRunNext();
        }
      });
    }
  }
}

/// 内部任务包装
class _QueueTask {
  static int _idCounter = 0;
  final String tripId;
  final Future<void> Function() task;
  int retries;
  final int id;

  _QueueTask(this.tripId, this.task, this.retries) : id = _idCounter++;

  Future<void> run() => task();
}
