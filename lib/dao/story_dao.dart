import 'dart:async';
import 'package:dio/dio.dart';
import 'package:nextsticker2/model/article_model.dart';

//const String urlBase = "https://nextsticker.cn/";
//const String urlBase = "http://10.0.2.2:4000/";
//const String urlBase = "http://localhost:4000/";
const String urlBase = "http://172.20.10.13:4000/";

const urL = '${urlBase}api/trip/getAllStory?page=';
const poMicroURL = '${urlBase}api/trip/newItem';
const clickLikeURL = '${urlBase}api/trip/clickLike';
const getStory = '${urlBase}api/trip/getStoryById?_id=';
const poCommentURL = '${urlBase}api/trip/poComment';
const fetchByAuthorURL = '${urlBase}api/trip/getStoryByAuthor?page=';
const likeOrCollectURL = '${urlBase}api/trip/getLikeOrCollectStoryByAuthor?page=';
const deleteURL = '${urlBase}api/trip/deleteStoryById';

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