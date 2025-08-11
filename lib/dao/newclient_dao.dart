import 'dart:async';
import 'package:dio/dio.dart';
import 'package:nextsticker2/model/travel_model.dart';

const String urlBase = "https://nextsticker.cn/";
//const String urlBase = "http://10.0.2.2:4000/";
//const String urlBase = "http://localhost:4000/";
//const String urlBase = "http://172.20.10.13:4000/";

const url = '${urlBase}api/users/newClient';
const loginUrl = '${urlBase}api/users/login';
const tokenUrl = '${urlBase}api/trip/getUploadToken';
const registerUrl = '${urlBase}api/users';

class ClientDao{
  static Future create(data) async{
    final response = await Dio().post(url, data:data);
    if (response.statusCode == 200) {
      //print(response.data);
      return response.data ?? '';
    } else {
      throw Exception('Failed to load data!');
    }
  }
}

class LoginDao{
  static Future login(data) async{
    final response = await Dio().post(loginUrl, data:data);
    if(response.data == ''){
      return AuthModel(
        like: [], 
        comment: [], 
        collect: [], 
        follow: [], 
        followed: []
      );
    }else {
      return AuthModel.fromJson(response.data);
    } 
  }

  static Future register(data) async{
    final response = await Dio().post(registerUrl, data:data);
    if (response.statusCode == 200) {
      if(response.data == '此用户名已经注册！'){
        return '此用户名已经注册！';
      }if(response.data == '未授权！'){
        return '未授权！';
      }else {
        return AuthModel.fromJson(response.data);
      } 
    } else if(response.statusCode == 401){
      //print(401);
      return '授权码错误！';
    } else {
      throw Exception('Failed to load data!');
    }
  }
}

class Micro{
  static Future getToken(string) async{
    final token = await Dio().get('$tokenUrl?type=$string');
    return token.data;
  }

  static Future micro(data) async{
    final response = await Dio().post(loginUrl, data:data);
    if(response.data == ''){
      return null;
    }else {
      return AuthModel.fromJson(response.data);
    } 
  }
}