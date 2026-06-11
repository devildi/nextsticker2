import 'dart:async';
import 'package:dio/dio.dart';
import 'dart:convert'; 
import 'package:nextsticker2/model/travel_model.dart';
import 'package:nextsticker2/tools/tools.dart';

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
      //print(response.data);
      return BingCover(bingUrl: response.data);
    } else if (response.statusCode == 204){
      return BingCover(bingUrl: '网络出错了，请自主填写！或稍后再试！！');
    }
    else {
      throw Exception('Failed to load data!!');
    }
  }

  static Future<BingCover> getBing(str) async{
    //print('${URLForAllTrip}uid=$uid&page=${1}');
    final response = await Dio().get('${getBingPic}point=$str');
    if (response.statusCode == 200) {
      //print(response.data);
      return BingCover(bingUrl: response.data);
    } else {
      //print(204);
      return BingCover(bingUrl: 'https://s21.ax1x.com/2025/08/04/pVUP4XQ.jpg');
    }
  }

  static Future getLocation(str) async{
    //print('${URLForAllTrip}uid=$uid&page=${1}');
    final response = await Dio().get('${getLocationUrl}point=$str');
    if (response.statusCode == 200) {
      //print(response.data);
      return BingCover(bingUrl: response.data);
    } else {
      //print(204);
      return BingCover(bingUrl: '123.454343,41.797344');
    }
  }

  static Future<TravelModel> fetch(uid) async{
    final response = await Dio().get(urL + uid);
    if (response.statusCode == 200) {
      
      return TravelModel.fromJson(response.data);
    } else if (response.statusCode == 204){
      return TravelModel(detail: []);
    }
    else {
      throw Exception('Failed to load data!!');
    }
  }

  static Future<AllTrip> fetchAll(uid, page) async{
    //print('${URLForAllTrip}uid=$uid&page=${1}');
    final response = await Dio().get('${urLForAllTrip}uid=$uid&page=$page');
    if (response.statusCode == 200) {
      //print(response.data);
      return AllTrip.fromJson(response.data);
    } else if (response.statusCode == 204){
      return AllTrip(allTripList: []);
    }
    else {
      throw Exception('Failed to load data!!');
    }
  }

  static Future<AllTrip> fetchAllByDescription(string) async{
    //print('${URLForAllTrip}uid=${uid}&page=${1}');
    final response = await Dio().get('${urLForDescriptedTrip}description=$string');
    if (response.statusCode == 200) {
      return AllTrip.fromJson(response.data);
    } else if (response.statusCode == 204){
      return AllTrip(allTripList: []);
    }
    else {
      throw Exception('Failed to load data!!');
    }
  }

  static Future<TravelModel> save(data) async{
    final response = await Dio().post(saveURL, data:data);
    if(response.data == ''){
      return TravelModel(detail: []);
    }else {
      return TravelModel.fromJson(response.data);
    } 
  }

  static Future deleteTrip(uid) async{
    final response = await Dio().post(deleteTripUrl, data: {'uid': uid});
    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception('Failed to delete trip!');
    }
  }

  static Future updatePoint(uid, name, des, picURL) async{
    final response = await Dio().post(updatePointURL, data: {
      'uid': uid,
      'nameOfScence':name,
      'des': des,
      'picURL': picURL
    });
    if (response.statusCode == 200) {
      return TravelModel.fromJson(response.data);
    } else {
      throw Exception('Failed to delete trip!');
    }
  }
}