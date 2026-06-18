import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nextsticker2/dao/travel_dao.dart';
import 'package:nextsticker2/dao/story_dao.dart';
import 'package:nextsticker2/model/travel_model.dart';
import 'package:nextsticker2/model/article_model.dart';

class SyncHelper {
  // Sync Options:
  // 1: Merge Server Data (合并服务器数据)
  // 2: Overwrite Server Data (覆盖服务器数据)
  // 3: Overwrite Local Data (覆盖本地数据)

  /// 检查本地与服务器数据是否存在差异。
  /// 返回 true 表示需要同步，返回 false 表示数据完全一致。
  static Future<bool> needsSync() async {
    final prefs = await SharedPreferences.getInstance();

    // --- 检查行程 ---
    try {
      final serverAll = await TravelDao.fetchAllFromServer('', 9999);
      final String? tripsJson = prefs.getString('local_trips');
      List<TravelModel> localTrips = [];
      if (tripsJson != null && tripsJson.isNotEmpty) {
        try {
          final List<dynamic> decoded = json.decode(tripsJson);
          localTrips = decoded.map((item) => TravelModel.fromJson(item)).toList();
        } catch (_) {}
      }
      final serverUids = serverAll.allTripList.map((t) => t.uid).toSet();
      final localUids = localTrips.map((t) => t.uid).toSet();
      if (!setEquals(serverUids, localUids)) return true;
    } catch (e) {
      debugPrint('needsSync - 行程检查失败: $e');
      return true; // 无法检查时默认认为需要同步
    }

    // --- 检查故事 ---
    try {
      final serverStories = await StoryDao.fetchFromServer(9999);
      final String? storiesJson = prefs.getString('local_stories');
      List<ArticleModel> localStories = [];
      if (storiesJson != null && storiesJson.isNotEmpty) {
        try {
          final List<dynamic> decoded = json.decode(storiesJson);
          localStories = decoded.map((item) => ArticleModel.fromJson(item)).toList();
        } catch (_) {}
      }
      final serverIds = serverStories.storyList.map((s) => s.articleId).toSet();
      final localIds = localStories.map((s) => s.articleId).toSet();
      if (!setEquals(serverIds, localIds)) return true;
    } catch (e) {
      debugPrint('needsSync - 故事检查失败: $e');
      return true; // 无法检查时默认认为需要同步
    }

    return false; // 数据完全一致
  }

  static Future<void> syncTrips({
    required int option,
    required AuthModel auth,
    required Function(String) onProgress,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Helper to get local trips
    Future<List<TravelModel>> getLocalTrips() async {
      final String? tripsJson = prefs.getString('local_trips');
      if (tripsJson == null || tripsJson.isEmpty) return [];
      try {
        final List<dynamic> decoded = json.decode(tripsJson);
        return decoded.map((item) => TravelModel.fromJson(item)).toList();
      } catch (_) {
        return [];
      }
    }
    
    // Helper to save local trips
    Future<void> saveLocalTrips(List<TravelModel> trips) async {
      final String tripsJson = json.encode(trips.map((e) => e.toJson()).toList());
      await prefs.setString('local_trips', tripsJson);
    }

    if (option == 1) {
      // MERGE TRIPS
      onProgress('正在获取服务器行程数据...');
      AllTrip serverAll;
      try {
        serverAll = await TravelDao.fetchAllFromServer('', 9999);
      } catch (e) {
        throw Exception('下载服务器行程数据失败: $e');
      }
      
      onProgress('正在获取本地行程数据...');
      List<TravelModel> localTrips = await getLocalTrips();
      
      // Update any local trips with empty designer to current logged-in user name
      if (auth.name.isNotEmpty) {
        for (var trip in localTrips) {
          if (trip.designer.isEmpty) {
            trip.designer = auth.name;
          }
        }
      }
      
      onProgress('正在合并行程数据...');
      final Map<String, TravelModel> mergedMap = {};
      
      // Populate with server trips
      for (var trip in serverAll.allTripList) {
        mergedMap[trip.uid] = trip;
      }
      
      // Overwrite/insert with local trips (keeps user's local versions)
      for (var trip in localTrips) {
        mergedMap[trip.uid] = trip;
      }
      
      final mergedList = mergedMap.values.toList();
      
      // Upload/Save merged trips to server (only for user's own trips)
      onProgress('正在同步行程到服务器...');
      List<String> errors = [];
      for (var trip in mergedList) {
        if (trip.designer == auth.name || auth.name.isEmpty) {
          try {
            await TravelDao.saveToServer(trip.toJson());
          } catch (e) {
            errors.add('上传行程 "${trip.tripName}" 失败: $e');
          }
        }
      }
      if (errors.isNotEmpty) {
        throw Exception(errors.join('; '));
      }
      
      // Save locally
      await saveLocalTrips(mergedList);
      
    } else if (option == 2) {
      // OVERWRITE SERVER WITH LOCAL TRIPS
      onProgress('正在获取本地行程数据...');
      List<TravelModel> localTrips = await getLocalTrips();
      
      onProgress('正在清理服务器上您的行程数据...');
      try {
        final serverAll = await TravelDao.fetchAllFromServer('', 9999);
        for (var trip in serverAll.allTripList) {
          // Only delete on server if auth.name is not empty and match designer
          if (auth.name.isNotEmpty && trip.designer == auth.name) {
            await TravelDao.deleteTripOnServer(trip.uid);
          }
        }
      } catch (e) {
        throw Exception('清除服务器旧行程失败: $e');
      }
      
      onProgress('正在上传本地行程到服务器...');
      List<String> errors = [];
      for (var trip in localTrips) {
        if (trip.designer.isEmpty && auth.name.isNotEmpty) {
          trip.designer = auth.name;
        }
        if (trip.designer == auth.name || auth.name.isEmpty) {
          try {
            await TravelDao.saveToServer(trip.toJson());
          } catch (e) {
            errors.add('上传行程 "${trip.tripName}" 失败: $e');
          }
        }
      }
      if (errors.isNotEmpty) {
        throw Exception(errors.join('; '));
      }
      await saveLocalTrips(localTrips);
      
    } else if (option == 3) {
      // OVERWRITE LOCAL WITH SERVER TRIPS
      onProgress('正在下载服务器行程数据...');
      try {
        final serverAll = await TravelDao.fetchAllFromServer('', 9999);
        await saveLocalTrips(serverAll.allTripList);
      } catch (e) {
        throw Exception('下载服务器行程覆盖本地失败: $e');
      }
    }
  }

  static Future<void> syncStories({
    required int option,
    required AuthModel auth,
    required Function(String) onProgress,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Helper to get local stories
    Future<List<ArticleModel>> getLocalStories() async {
      final String? storiesJson = prefs.getString('local_stories');
      if (storiesJson == null || storiesJson.isEmpty) return [];
      try {
        final List<dynamic> decoded = json.decode(storiesJson);
        return decoded.map((item) => ArticleModel.fromJson(item)).toList();
      } catch (_) {
        return [];
      }
    }
    
    // Helper to save local stories
    Future<void> saveLocalStories(List<ArticleModel> stories) async {
      final String storiesJson = json.encode(stories.map((e) => e.toJson()).toList());
      await prefs.setString('local_stories', storiesJson);
    }

    if (option == 1) {
      // MERGE STORIES
      onProgress('正在获取服务器故事数据...');
      AllStoryModel serverStories;
      try {
        serverStories = await StoryDao.fetchFromServer(9999);
      } catch (e) {
        throw Exception('下载服务器故事数据失败: $e');
      }
      
      onProgress('正在获取本地故事数据...');
      List<ArticleModel> localStories = await getLocalStories();
      
      onProgress('正在合并故事数据...');
      final Map<String, ArticleModel> mergedMap = {};
      
      // Populate with server stories
      for (var story in serverStories.storyList) {
        final String key = story.articleURL.isNotEmpty ? story.articleURL : story.articleId;
        mergedMap[key] = story;
      }
      
      // Upload/Save local-only stories (stories that are local but not on server)
      onProgress('正在同步本地故事到服务器...');
      List<String> errors = [];
      for (var localStory in localStories) {
        final String key = localStory.articleURL.isNotEmpty ? localStory.articleURL : localStory.articleId;
        
        if (!mergedMap.containsKey(key)) {
          if (localStory.author.name == auth.name || localStory.author.uid == auth.uid || localStory.author.name.isEmpty || localStory.author.uid.isEmpty || auth.name.isEmpty) {
            try {
              final Map<String, dynamic> uploadData = {
                'articleName': localStory.articleName,
                'articleContent': localStory.articleContent,
                'picURL': localStory.picURL,
                'videoURL': localStory.videoURL,
                'width': localStory.width,
                'height': localStory.height,
                'articleType': localStory.articleType,
                'album': localStory.album.map((e) => e.toJson()).toList(),
                if (auth.uid.isNotEmpty) 'author': auth.uid, // Omit if empty to prevent MongoDB CastError
                'articleURL': localStory.articleURL,
              };
              await StoryDao.poMicroOnServer(uploadData);
            } catch (e) {
              errors.add('发布故事 "${localStory.articleName}" 失败: $e');
            }
          }
        }
      }
      if (errors.isNotEmpty) {
        throw Exception(errors.join('; '));
      }
      
      onProgress('正在下载合并后的完整数据...');
      try {
        serverStories = await StoryDao.fetchFromServer(9999);
      } catch (e) {
        throw Exception('下载完整故事失败: $e');
      }
      
      // Save merged stories to local cache
      await saveLocalStories(serverStories.storyList);
      
    } else if (option == 2) {
      // OVERWRITE SERVER WITH LOCAL STORIES
      onProgress('正在获取本地故事数据...');
      List<ArticleModel> localStories = await getLocalStories();
      
      onProgress('正在清理服务器上您的故事数据...');
      try {
        final serverStories = await StoryDao.fetchFromServer(9999);
        for (var story in serverStories.storyList) {
          // Only delete user-owned server stories if auth.name is not empty
          if (auth.name.isNotEmpty && (story.author.name == auth.name || story.author.uid == auth.uid)) {
            List<String> keys = [];
            if (story.picURL.isNotEmpty) keys.add(story.picURL);
            if (story.videoURL.isNotEmpty) keys.add(story.videoURL);
            if (story.album.isNotEmpty) {
              keys.addAll(story.album.map((e) => e.key).toList());
            }
            await StoryDao.deleteStoryOnServer(story.articleId, keys);
          }
        }
      } catch (e) {
        throw Exception('清理服务器旧故事失败: $e');
      }
      
      onProgress('正在上传本地故事到服务器...');
      List<String> errors = [];
      for (var story in localStories) {
        if (story.author.name == auth.name || story.author.uid == auth.uid || story.author.name.isEmpty || story.author.uid.isEmpty || auth.name.isEmpty) {
          try {
            final Map<String, dynamic> uploadData = {
              'articleName': story.articleName,
              'articleContent': story.articleContent,
              'picURL': story.picURL,
              'videoURL': story.videoURL,
              'width': story.width,
              'height': story.height,
              'articleType': story.articleType,
              'album': story.album.map((e) => e.toJson()).toList(),
              if (auth.uid.isNotEmpty) 'author': auth.uid, // Omit if empty to prevent MongoDB CastError
              'articleURL': story.articleURL,
            };
            await StoryDao.poMicroOnServer(uploadData);
          } catch (e) {
            errors.add('发布故事 "${story.articleName}" 失败: $e');
          }
        }
      }
      if (errors.isNotEmpty) {
        throw Exception(errors.join('; '));
      }
      
      onProgress('正在更新本地缓存...');
      try {
        final updatedServerStories = await StoryDao.fetchFromServer(9999);
        await saveLocalStories(updatedServerStories.storyList);
      } catch (e) {
        throw Exception('拉取更新后的故事缓存失败: $e');
      }
      
    } else if (option == 3) {
      // OVERWRITE LOCAL WITH SERVER STORIES
      onProgress('正在下载服务器故事数据...');
      try {
        final serverStories = await StoryDao.fetchFromServer(9999);
        await saveLocalStories(serverStories.storyList);
      } catch (e) {
        throw Exception('下载服务器故事覆盖本地失败: $e');
      }
    }
  }
}
