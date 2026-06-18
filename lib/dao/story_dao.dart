import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:nextsticker2/model/article_model.dart';
import 'package:nextsticker2/model/travel_model.dart';
import 'package:nextsticker2/tools/tools.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

String urlBase = CommonUtils.developmentMode ? CommonUtils.lanUrl : "https://nextsticker.cn/";

String urL = '${urlBase}api/trip/getAllStory?page=';
String poMicroURL = '${urlBase}api/trip/newItem';
String clickLikeURL = '${urlBase}api/trip/clickLike';
String getStory = '${urlBase}api/trip/getStoryById?_id=';
String poCommentURL = '${urlBase}api/trip/poComment';
String fetchByAuthorURL = '${urlBase}api/trip/getStoryByAuthor?page=';
String likeOrCollectURL = '${urlBase}api/trip/getLikeOrCollectStoryByAuthor?page=';
String deleteURL = '${urlBase}api/trip/deleteStoryById';

class StoryDao{
  // Local cache helper methods
  static Future<List<ArticleModel>> _loadLocalStories() async {
    final prefs = await SharedPreferences.getInstance();
    final String? storiesJson = prefs.getString('local_stories');
    if (storiesJson == null || storiesJson.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> decoded = json.decode(storiesJson);
      return decoded.map((item) => ArticleModel.fromJson(item)).toList();
    } catch (e) {
      debugPrint('Error loading local stories: $e');
      return [];
    }
  }

  static Future<void> _saveLocalStories(List<ArticleModel> stories) async {
    final prefs = await SharedPreferences.getInstance();
    final String storiesJson = json.encode(stories.map((e) => e.toJson()).toList());
    await prefs.setString('local_stories', storiesJson);
  }

  static Future<AuthModel> _getCurrentAuthUser() async {
    final prefs = await SharedPreferences.getInstance();
    final String? authStr = prefs.getString('auth');
    if (authStr != null && authStr.isNotEmpty) {
      try {
        final decoded = json.decode(authStr);
        return AuthModel.fromJson(decoded);
      } catch (e) {
        debugPrint('Error decoding auth: $e');
      }
    }
    return AuthModel(like: [], comment: [], collect: [], follow: [], followed: []);
  }

  // --- Local CRUD Methods ---

  static Future<AllStoryModel> fetch(index) async{
    final stories = await _loadLocalStories();
    final subset = stories.take(index * 20).toList();
    return AllStoryModel(storyList: subset);
  }

  static Future<AllStoryModel> fetchByAuthor(index, uid) async{
    final stories = await _loadLocalStories();
    final subset = stories.where((story) => story.author.uid == uid || story.author.name == uid).take(index * 20).toList();
    return AllStoryModel(storyList: subset);
  }

  static Future<AllStoryModel> likeOrCollect(index, uid, type) async{
    final stories = await _loadLocalStories();
    List<ArticleModel> filtered;
    if (type == 'likes') {
      filtered = stories.where((story) => story.likes.any((user) => user.uid == uid)).toList();
    } else {
      filtered = stories.where((story) => story.collects.any((user) => user.uid == uid)).toList();
    }
    final subset = filtered.take(index * 20).toList();
    return AllStoryModel(storyList: subset);
  }

  static Future poMicro(data)async {
    final AuthModel currentAuth = await _getCurrentAuthUser();
    
    const cdnBase = "https://cdn.nextsticker.cn/";
    
    String getAbsoluteUrl(String path) {
      if (path.isEmpty) return '';
      if (path.startsWith('http://') || path.startsWith('https://')) {
        return path;
      }
      return '$cdnBase$path';
    }

    List<dynamic> album = data['album'] ?? [];
    List<Map<String, dynamic>> updatedAlbum = [];
    for (var item in album) {
      if (item is Map) {
        var key = item['key'] ?? '';
        var updatedItem = Map<String, dynamic>.from(item);
        updatedItem['key'] = getAbsoluteUrl(key.toString());
        updatedAlbum.add(updatedItem);
      } else {
        updatedAlbum.add(item);
      }
    }
    
    final Map<String, dynamic> uploadData = {
      'articleName': data['articleName'] ?? '',
      'picURL': getAbsoluteUrl(data['picURL'] ?? ''),
      'videoURL': getAbsoluteUrl(data['videoURL'] ?? ''),
      'articleURL': '', 
      'width': data['width'] ?? 0,
      'height': data['height'] ?? 0,
      'articleContent': data['articleContent'] ?? '',
      'articleType': data['articleType'] ?? 2,
      'album': updatedAlbum,
      if (currentAuth.uid.isNotEmpty) 'author': currentAuth.uid,
    };
    
    // 1. Upload to server directly
    final serverResponse = await poMicroOnServer(uploadData);
    if (serverResponse == null) {
      throw Exception('服务器返回空数据');
    }
    
    // 2. Parse the server-populated story
    final ArticleModel serverStory = ArticleModel.fromJson(serverResponse);
    
    // 3. Save to local SQLite cache
    final localStories = await _loadLocalStories();
    localStories.insert(0, serverStory);
    await _saveLocalStories(localStories);
    
    return 'newItem';
  }

  static Future clickLike(data)async {
    final String storyId = data['id'];
    final String uid = data['uid'];
    final stories = await _loadLocalStories();
    final idx = stories.indexWhere((s) => s.articleId == storyId);
    if (idx != -1) {
      final story = stories[idx];
      final likes = List<AuthModel>.from(story.likes);
      final userIdx = likes.indexWhere((u) => u.uid == uid);
      
      if (userIdx != -1) {
        likes.removeAt(userIdx);
      } else {
        final AuthModel currentAuth = await _getCurrentAuthUser();
        final AuthModel likeUser = currentAuth.uid == uid 
            ? currentAuth 
            : AuthModel(
                uid: uid, 
                name: 'User', 
                like: [], comment: [], collect: [], follow: [], followed: []
              );
        likes.add(likeUser);
      }
      
      final Map<String, dynamic> updatedMap = story.toJson();
      updatedMap['likes'] = likes.map((e) => e.toJson()).toList();
      final updatedStory = ArticleModel.fromJson(updatedMap);
      
      stories[idx] = updatedStory;
      await _saveLocalStories(stories);
      return updatedStory;
    }
    throw Exception('Story not found locally');
  }

  static Future poComment(data)async {
    final String storyId = data['whichArticle'];
    final String content = data['content'];
    final String whoseContent = data['whoseContent'];
    final stories = await _loadLocalStories();
    final idx = stories.indexWhere((s) => s.articleId == storyId);
    if (idx != -1) {
      final story = stories[idx];
      final comments = List<Comment>.from(story.comments);
      
      final AuthModel currentAuth = await _getCurrentAuthUser();
      final AuthModel commentUser = currentAuth.uid == whoseContent 
          ? currentAuth 
          : AuthModel(
              uid: whoseContent, 
              name: 'User', 
              like: [], comment: [], collect: [], follow: [], followed: []
            );
      
      comments.add(Comment(content: content, whoseContent: commentUser));
      
      final Map<String, dynamic> updatedMap = story.toJson();
      updatedMap['comments'] = comments.map((e) => e.toJson()).toList();
      final updatedStory = ArticleModel.fromJson(updatedMap);
      
      stories[idx] = updatedStory;
      await _saveLocalStories(stories);
      return updatedStory;
    }
    throw Exception('Story not found locally');
  }

  static Future getStoryByID(id)async {
    final stories = await _loadLocalStories();
    return stories.firstWhere((s) => s.articleId == id);
  }

  static Future deleteStory(id, keysArray) async {
    final stories = await _loadLocalStories();
    stories.removeWhere((s) => s.articleId == id);
    await _saveLocalStories(stories);
    return ResultModel(ok: 1, n: 1, deletedCount: 1);
  }

  // --- Server Fallback/Sync Methods ---

  static Future<AllStoryModel> fetchFromServer(index) async{
    final response = await Dio().get('$urL$index');
    if (response.statusCode == 200) {
      return AllStoryModel.fromJson(response.data);
    } else {
      throw Exception('Failed to load data from server!');
    }
  }

  static Future<AllStoryModel> fetchByAuthorFromServer(index, uid) async{
    final response = await Dio().get('$fetchByAuthorURL$index&uid=$uid');
    if (response.statusCode == 200) {
      return AllStoryModel.fromJson(response.data);
    } else {
      throw Exception('Failed to load data from server!');
    }
  }

  static Future<AllStoryModel> likeOrCollectFromServer(index, uid, type) async{
    final response = await Dio().get('$likeOrCollectURL$index&type=$type&uid=$uid');
    if (response.statusCode == 200) {
      return AllStoryModel.fromJson(response.data);
    } else {
      throw Exception('Failed to load data from server!');
    }
  }

  static Future poMicroOnServer(data)async {
    final response = await Dio().post(poMicroURL, data:data);
    if(response.data != null){
      return response.data;
    }else {
      throw Exception('NetWork Error!');
    }
  }

  static Future clickLikeOnServer(data)async {
    final response = await Dio().post(clickLikeURL, data:data);
    if(response.data != null){
      return ArticleModel.fromJson(response.data);
    }else {
      throw Exception('NetWork Error!');
    }
  }

  static Future poCommentOnServer(data)async {
    final response = await Dio().post(poCommentURL, data:data);
    if(response.data != null){
      return ArticleModel.fromJson(response.data);
    }else {
      throw Exception('NetWork Error!');
    }
  }

  static Future getStoryByIDFromServer(id)async {
    final response = await Dio().get('$getStory$id');
    if(response.data != null){
      return ArticleModel.fromJson(response.data);
    }else {
      throw Exception('NetWork Error!');
    }
  }

  static Future deleteStoryOnServer(id, keysArray) async {
    final response = await Dio().post(deleteURL, data:{ 'id': id,  'key': keysArray});
    if(response.data != null){
      return ResultModel.fromJson(response.data);
    }else {
      throw Exception('NetWork Error!');
    }
  }
}