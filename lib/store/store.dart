import 'package:flutter/material.dart';
import 'package:nextsticker2/model/travel_model.dart';

class UserData with ChangeNotifier {
  UserData({
    required this.userData , 
    this.domestic = true, 
    this.whichForDrawer = -1,
    this.netWorkStatus = true, 
    required this.traficInfo,
    this.loadingRouteState = false,
    required this.auth,
    required this.chatArray,
    required this.chatUsers,
    this.numInChatroom = 0,
    required this.trips,
    this.loading = false,
    required this.points ,
    required this.cloneData,
    required this.index,
    required this.picsFromAlbum,
    this.picBing = '',
    this.des = '',
    this.category = 0,
    this.fetchImgStatus = '正在完善信息中，请耐心等待...',
    this.swiperIndex = 0,
  });
  
  int category;
  int swiperIndex;
  String fetchImgStatus;
  String picBing;
  String des;
  TravelModel userData;
  bool domestic;
  int whichForDrawer;
  bool netWorkStatus;
  List traficInfo;
  bool loadingRouteState;
  AuthModel auth;
  List chatArray;
  List chatUsers;
  int numInChatroom;
  List trips;
  bool loading;
  List points;
  TravelModel cloneData;
  List index;
  List picsFromAlbum;

  void setCategory(int a){
    category = a;
    notifyListeners();
  }

  void setSwiperIndex(int a){
    swiperIndex = a;
    notifyListeners();
  }

  void setFetchImgStatus(String a){
    fetchImgStatus = a;
    notifyListeners();
  }

  void setPicBing(String a){
    picBing = a;
    notifyListeners();
  }

  void setDes(String a){
    des = a;
    notifyListeners();
  }

  void setPicsFromAlbum(List a){
    picsFromAlbum = a;
    notifyListeners();
  }

  void setIndex(List a){
    index = a;
    notifyListeners();
  }

  void setPoints(List points){
    this.points = points;
    notifyListeners();
  }

  void setNumInChatroom(int num){
    numInChatroom = num;
    notifyListeners();
  }

  void setUserData(TravelModel dartObj){
    userData = dartObj;
    notifyListeners();
  }

  void setDomestic(bool flag){
    domestic = flag;
    notifyListeners();
  }

  void setWhichForDrawer(int whichForDrawer){
    this.whichForDrawer = whichForDrawer;
    notifyListeners();
  }

  void setNetWorkStatus(flag){
    netWorkStatus = flag;
    notifyListeners();
  }

  void setTrafficInfo(info){
    traficInfo = info;
    notifyListeners();
  }

  void setLoadingRouteState(flag){
    loadingRouteState = flag;
    notifyListeners();
  }

  void setAuth(auth){
    this.auth = auth;
    notifyListeners();
  }

  void setchatUsers(str){
    chatUsers = str;
    notifyListeners();
  }

  void setchatArray(obj){
    if(chatArray.isEmpty == true){
      List a = [];
      a.add(obj);
      chatArray = a;
    } else {
      List a = chatArray;
      a.add(obj);
      chatArray = a;
    }
    notifyListeners();
  }

  void setTrips(List tips){
    trips = tips;
    notifyListeners();
  }

  void setLoading(bool flag){
    loading = flag;
    notifyListeners();
  }

  void setCloneData(TravelModel dartObj){
    cloneData = dartObj;
    notifyListeners();
  }
}