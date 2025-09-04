import 'dart:async';
import 'package:dio/dio.dart';
import 'package:nextsticker2/model/article_model.dart';
import 'package:nextsticker2/tools/tools.dart';

String urlBase = CommonUtils.developmentMode ? "http://172.20.10.13:4000/" : "https://nextsticker.cn/";

String urL = '${urlBase}api/trip/getAllStory?page=';
String poMicroURL = '${urlBase}api/trip/newItem';
String clickLikeURL = '${urlBase}api/trip/clickLike';
String getStory = '${urlBase}api/trip/getStoryById?_id=';
String poCommentURL = '${urlBase}api/trip/poComment';
String fetchByAuthorURL = '${urlBase}api/trip/getStoryByAuthor?page=';
String likeOrCollectURL = '${urlBase}api/trip/getLikeOrCollectStoryByAuthor?page=';
String deleteURL = '${urlBase}api/trip/deleteStoryById';

class StoryDao{
  static Future<AllStoryModel> fetch(index) async{
    //print('$URL$index');
    final response = await Dio().get('$urL$index');
    if (response.statusCode == 200) {
      //print(response.data);
      return AllStoryModel.fromJson(response.data);
    } else {
      throw Exception('Failed to load data!');
    }
  }

  static Future<AllStoryModel> fetchByAuthor(index, uid) async{
    //print('$URL$index');
    final response = await Dio().get('$fetchByAuthorURL$index&uid=$uid');
    if (response.statusCode == 200) {
      //print(response.data);
      return AllStoryModel.fromJson(response.data);
    } else {
      throw Exception('Failed to load data!');
    }
  }

  static Future<AllStoryModel> likeOrCollect(index, uid, type) async{
    //print('$URL$index');
    final response = await Dio().get('$likeOrCollectURL$index&type=$type&uid=$uid');
    if (response.statusCode == 200) {
      //print(response.data);
      return AllStoryModel.fromJson(response.data);
    } else {
      throw Exception('Failed to load data!');
    }
  }

  static Future poMicro(data)async {
    final response = await Dio().post(poMicroURL, data:data);
    if(response.data != null){
      return response.data;
    }else {
      throw Exception('NetWork Error!');
    }
  }

  static Future clickLike(data)async {
    final response = await Dio().post(clickLikeURL, data:data);
    if(response.data != null){
      return ArticleModel.fromJson(response.data);
    }else {
      throw Exception('NetWork Error!');
    }
  }

  static Future poComment(data)async {
    final response = await Dio().post(poCommentURL, data:data);
    if(response.data != null){
      return ArticleModel.fromJson(response.data);
    }else {
      throw Exception('NetWork Error!');
    }
  }

  static Future getStoryByID(id)async {
    final response = await Dio().get('$getStory$id');
    if(response.data != null){
      return ArticleModel.fromJson(response.data);
    }else {
      throw Exception('NetWork Error!');
    }
  }

  static Future deleteStory(id, keysArray) async {
    final response = await Dio().post(deleteURL, data:{ 'id': id,  'key': keysArray});
    if(response.data != null){
      return ResultModel.fromJson(response.data);
    }else {
      throw Exception('NetWork Error!');
    }
  }
}