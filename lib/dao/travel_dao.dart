import 'dart:async';
import 'package:dio/dio.dart';
import 'dart:convert'; 
import 'package:nextsticker2/model/travel_model.dart';
import 'package:nextsticker2/tools/tools.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

String urlBase = CommonUtils.developmentMode ? CommonUtils.lanUrl : "https://nextsticker.cn/";

String urL = '${urlBase}api/trip/get?uid=';
String urLForAllTrip = '${urlBase}api/trip/getAllTrip?';
String urLForDescriptedTrip = '${urlBase}api/trip/getDescriptedTrip?';
String saveURL = '${urlBase}api/trip/new';
String getBingPic = '${urlBase}api/trip/getBingImg?';
String getLocationUrl = '${urlBase}api/trip/getLocation?';
String getDesURL = '${urlBase}api/chat/getDes?';
String getInfosURL = '${urlBase}api/chat/getInfos?';
String formatTripUrl = '${urlBase}api/chat/formatTripFromLLM?';
String deleteTripUrl = '${urlBase}api/trip/deleteTrip';
String updatePointURL = '${urlBase}api/trip/updatePoint';

class TravelDao{
  // Local cache helper methods
  static Future<List<TravelModel>> _loadLocalTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tripsJson = prefs.getString('local_trips');
    if (tripsJson == null || tripsJson.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> decoded = json.decode(tripsJson);
      return decoded.map((item) => TravelModel.fromJson(item)).toList();
    } catch (e) {
      debugPrint('Error loading local trips: $e');
      return [];
    }
  }

  static Future<void> _saveLocalTrips(List<TravelModel> trips) async {
    final prefs = await SharedPreferences.getInstance();
    final String tripsJson = json.encode(trips.map((e) => e.toJson()).toList());
    await prefs.setString('local_trips', tripsJson);
  }

  // --- Local CRUD Methods ---

  static Future<TravelModel> fetch(uid) async{
    final trips = await _loadLocalTrips();
    return trips.firstWhere(
      (trip) => trip.uid == uid,
      orElse: () => TravelModel(detail: []),
    );
  }

  static Future<AllTrip> fetchAll(uid, page) async{
    final trips = await _loadLocalTrips();
    // Prioritize/sort so the trip with the matching uid is at index 0
    if (uid != null && uid.isNotEmpty) {
      final int targetIdx = trips.indexWhere((t) => t.uid == uid);
      if (targetIdx != -1) {
        final target = trips.removeAt(targetIdx);
        trips.insert(0, target);
      }
    }
    // Limit to page * 20
    final int limit = page * 20;
    final subset = trips.take(limit).toList();
    return AllTrip(allTripList: subset);
  }

  static Future<AllTrip> fetchAllByDescription(string) async{
    final trips = await _loadLocalTrips();
    final filtered = trips.where((trip) {
      final tag = string.toLowerCase();
      return trip.city.toLowerCase().contains(tag) ||
             trip.country.toLowerCase().contains(tag) ||
             trip.tags.toLowerCase().contains(tag) ||
             trip.tripName.toLowerCase().contains(tag);
    }).toList();
    return AllTrip(allTripList: filtered);
  }

  static Future<TravelModel> save(data) async{
    final TravelModel newTrip = TravelModel.fromJson(data);
    if (newTrip.uid.isEmpty) {
      newTrip.uid = const Uuid().v4();
    }
    final trips = await _loadLocalTrips();
    final idx = trips.indexWhere((t) => t.uid == newTrip.uid);
    if (idx != -1) {
      trips[idx] = newTrip;
    } else {
      trips.insert(0, newTrip);
    }
    await _saveLocalTrips(trips);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('map_design_draft');
    return newTrip;
  }

  static Future deleteTrip(uid) async{
    final trips = await _loadLocalTrips();
    trips.removeWhere((t) => t.uid == uid);
    await _saveLocalTrips(trips);
    return {'ok': 1, 'n': 1, 'deletedCount': 1};
  }

  static Future updatePoint(uid, name, des, picURL) async{
    final trips = await _loadLocalTrips();
    final idx = trips.indexWhere((t) => t.uid == uid);
    if (idx != -1) {
      final trip = trips[idx];
      for (var day in trip.detail) {
        for (var point in day.dayList) {
          if (point.nameOfScence == name) {
            if (des != null) point.des = des;
            if (picURL != null) point.picURL = picURL;
          }
        }
      }
      trips[idx] = trip;
      await _saveLocalTrips(trips);
      return trip;
    }
    throw Exception('Trip not found locally');
  }

  static Future updateCover(uid, picURL) async {
    final trips = await _loadLocalTrips();
    final idx = trips.indexWhere((t) => t.uid == uid);
    if (idx != -1) {
      trips[idx].cover = picURL;
      await _saveLocalTrips(trips);
      return trips[idx];
    }
    throw Exception('Trip not found locally');
  }

  // --- Server Fallback/Sync Methods ---

  static Future<TravelModel> fetchFromServer(uid) async{
    final response = await Dio().get(urL + uid);
    if (response.statusCode == 200) {
      return TravelModel.fromJson(response.data);
    } else if (response.statusCode == 204){
      return TravelModel(detail: []);
    }
    else {
      throw Exception('Failed to load dataFromServer!!');
    }
  }

  static Future<AllTrip> fetchAllFromServer(uid, page) async{
    final response = await Dio().get('${urLForAllTrip}uid=$uid&page=$page');
    if (response.statusCode == 200) {
      return AllTrip.fromJson(response.data);
    } else if (response.statusCode == 204){
      return AllTrip(allTripList: []);
    }
    else {
      throw Exception('Failed to load dataFromServer!!');
    }
  }

  static Future<TravelModel> saveToServer(data) async{
    final response = await Dio().post(saveURL, data:data);
    if(response.data == ''){
      return TravelModel(detail: []);
    }else {
      return TravelModel.fromJson(response.data);
    } 
  }

  static Future deleteTripOnServer(uid) async{
    final response = await Dio().post(deleteTripUrl, data: {'uid': uid});
    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception('Failed to delete trip on server!');
    }
  }

  static Future updatePointOnServer(uid, name, des, picURL) async{
    final response = await Dio().post(updatePointURL, data: {
      'uid': uid,
      'nameOfScence':name,
      'des': des,
      'picURL': picURL
    });
    if (response.statusCode == 200) {
      return TravelModel.fromJson(response.data);
    } else {
      throw Exception('Failed to update point on server!');
    }
  }

  // --- LLM & Bing Helpers ---

  static Future<ReturnInfos> getInfos(str) async{
    final response = await Dio().get('${getInfosURL}chat=$str');
    if (response.statusCode == 200) {
      return ReturnInfos.fromJson(json.decode(response.data));
    }
    else {
      throw Exception('Failed to load data!!');
    }
  }

  static Future<TravelModel> fromLLM(str) async{
    final response = await Dio().get('${formatTripUrl}chat=$str');
    if (response.statusCode == 200) {
      return TravelModel.fromJson({
        'detail': json.decode(response.data)
      });
    } 
    else {
      throw Exception('Failed to load data!!');
    }
  }

  static Future<BingCover> getDes(str) async{
    final response = await Dio().get('${getDesURL}chat=$str');
    if (response.statusCode == 200) {
      return BingCover(bingUrl: response.data);
    } else if (response.statusCode == 204){
      return BingCover(bingUrl: '网络出错了，请自主填写！或稍后再试！！');
    }
    else {
      throw Exception('Failed to load data!!');
    }
  }

  static Future<BingCover> getBing(str) async{
    final response = await Dio().get('${getBingPic}point=$str');
    if (response.statusCode == 200) {
      return BingCover(bingUrl: response.data);
    } else {
      return BingCover(bingUrl: 'https://s21.ax1x.com/2025/08/04/pVUP4XQ.jpg');
    }
  }

  static Future getLocation(str) async{
    final response = await Dio().get('${getLocationUrl}point=$str');
    if (response.statusCode == 200) {
      return BingCover(bingUrl: response.data);
    } else {
      return BingCover(bingUrl: '123.454343,41.797344');
    }
  }

  static Future<String> handleImageFailure({
    required String uid,
    required String tripName,
    required String nameOfScence,
    required bool isCover,
  }) async {
    try {
      BingCover newImg = await getBing(nameOfScence);
      String newUrl = newImg.bingUrl;
      if (newUrl.isNotEmpty && 
          !newUrl.startsWith('网络出') && 
          newUrl != 'https://s21.ax1x.com/2025/08/04/pVUP4XQ.jpg') {
        if (isCover) {
          await Dio().post('${urlBase}api/trip/updatePointImg', data: {
            'url': newUrl,
            'tripName': tripName,
            'cover': true,
          });
          await updateCover(uid, newUrl);
        } else {
          await updatePoint(uid, nameOfScence, null, newUrl);
        }
        return newUrl;
      }
    } catch (e) {
      debugPrint('自动更新失效图片失败: $e');
    }
    return '';
  }
}