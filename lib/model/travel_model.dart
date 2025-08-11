import 'package:nextsticker2/model/article_model.dart';

class NewUser {
  final String wechat;
  final String destination;

  NewUser({
    required this.wechat,
    required this.destination,
  });

  factory NewUser.fromJson(Map<String, dynamic> json) {
    return NewUser(
      wechat: json["wechat"],
      destination: json["destination"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "width": wechat,
      "destination": destination,
    };
  }
}

class Comment {
  final String content;
  final AuthModel whoseContent;
  //final ArticleModel whichArticle;

  Comment({
    required this.content,
    required this.whoseContent,
    //this.whichArticle
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      content: json["content"],
      whoseContent: AuthModel.fromJson(json["whoseContent"]),
      //whichArticle: json["whichArticle"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "content": content,
      "whoseContent": whoseContent,
      //"whichArticle": this.whichArticle,
    };
  }
}

class BingCover {
  final String bingUrl;

  BingCover({
    required this.bingUrl,
  });

  factory BingCover.fromJson(Map<String, dynamic> json) {
    return BingCover(
      bingUrl: json["bingUrl"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "bingUrl": bingUrl
    };
  }
}

class ReturnInfos {
  final String city;
  final String country;
  final String tags;

  ReturnInfos({
    required this.city,
    required this.country,
    required this.tags,
  });

  factory ReturnInfos.fromJson(Map<String, dynamic> json) {
    return ReturnInfos(
      city: json["city"],
      country: json["country"],
      tags: json["tags"]
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "city": city,
      "country": country,
      "tags": tags
    };
  }
}

class ReturnBody {
  final String width;
  final String height;
  final String key;

  ReturnBody({
    required this.width,
    required this.height,
    required this.key,
  });

  factory ReturnBody.fromJson(Map<String, dynamic> json) {
    return ReturnBody(
      width: json["width"],
      height: json["height"],
      key: json["key"]
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "width": width,
      "height": height,
      "key": key
    };
  }
}

class AuthModel {
  final String name;
  final String uid;
  final String avatar;
  final List<ArticleModel> like;
  final List<ArticleModel> comment;
  final List<ArticleModel> collect;
  final List<AuthModel> follow;
  final List<AuthModel> followed;

  AuthModel({
    this.name = '',
    this.uid = '',
    this.avatar = '',
    required this.like,
    required this.comment,
    required this.collect,
    required this.follow,
    required this.followed,
  });

  factory AuthModel.fromJson(Map<String, dynamic> json) {
    return AuthModel(
      name: json["name"],
      uid: json["_id"],
      avatar: json["avatar"] ?? '',
      like: json['like'].length > 0 ? (json['like'] as List).map((i) => ArticleModel.fromJson(i)).toList() : [],
      comment: json['comment'].length > 0 ?(json['comment'] as List).map((i) => ArticleModel.fromJson(i)).toList(): [],
      collect: json['collect'].length > 0 ?(json['collect'] as List).map((i) => ArticleModel.fromJson(i)).toList(): [],
      follow: json['follow'].length > 0 ?(json['follow'] as List).map((i) => AuthModel.fromJson(i)).toList(): [],
      followed: json['followed'].length > 0 ?(json['followed'] as List).map((i) => AuthModel.fromJson(i)).toList(): [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "_id": uid,
      "avatar": avatar,
      "like": like,
      "comment": comment,
      "collect": collect,
      "follow": follow,
      "followed": followed,
    };
  }
}

class Points {
  final List<DetailModel> pointList;

  Points({
    required this.pointList
  });

  factory Points.fromJson(List json){
    return Points(
      pointList: json.map((i) => DetailModel.fromJson(i)).toList()
    );
  }

  List<dynamic> toJson(){
    return pointList.map((i) => i.toJson()).toList();
  }
}

class DetailModel {
  String nameOfScence;
  String longitude;
  String latitude;
  String des;
  String picURL;
  final bool pointOrNot;
  final String contructor;
  num category;
  bool done;

  DetailModel copy(){
    return DetailModel(
      nameOfScence: nameOfScence,
      longitude: longitude, 
      latitude: latitude, 
      des: des,
      picURL: picURL,
      pointOrNot: pointOrNot,
      contructor: contructor,
      category: category,
      done: done,
    );
  }

  DetailModel({
    this.nameOfScence = '', 
    this.longitude = '', 
    this.latitude = '', 
    this.des = '',
    this.picURL = '',
    this.pointOrNot = true,
    this.contructor = 'contructor',
    this.category = 0,
    this.done = false,
  });

  factory DetailModel.fromJson(Map<String, dynamic> json) {
    return DetailModel(
      nameOfScence: json["nameOfScence"],
      longitude: json["longitude"].toString(),
      latitude: json["latitude"].toString(),
      des: json["des"] ?? '',
      picURL: json["picURL"] ?? '',
      pointOrNot: json["pointOrNot"] ?? true,
      contructor: json["contructor"] ?? 'contructor',
      category: json["category"] ?? 0,
      done: json["done"] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "nameOfScence": nameOfScence,
      "longitude": longitude,
      "latitude": latitude,
      "des": des,
      "picURL": picURL,
      "pointOrNot": pointOrNot,
      "contructor": contructor,
      "category": category,
      "done": done,
    };
  }
}

class DayDetail {
  final List<DetailModel> dayList;

  DayDetail({
    required this.dayList
  });

  DayDetail copy(){
    List<DetailModel> copiedDayList = dayList.map((i) => i.copy()).toList();
    return DayDetail(dayList: copiedDayList);
  }
  
  factory DayDetail.fromJson(List json){
    return DayDetail(
      dayList: json.map((i) => DetailModel.fromJson(i)).toList()
    );
  }

  List<dynamic> toJson(){
    return dayList.map((i) => i.toJson()).toList();
  }
}

class TravelModel {
  final String uid;
  String tripName;
  String designer;
  String city;
  String country;
  String tags;
  final String cover;
  final num domestic;
  List<DayDetail> detail;

  TravelModel copy(){
    List<DayDetail> copiedDetail = detail.map((i) => i.copy()).toList();
    return TravelModel(
      uid: uid,
      tripName: tripName,
      designer: designer,
      detail: copiedDetail,
      domestic: domestic,
      city: city,
      country: country,
      tags: tags,
      cover: cover
    );
  }

  TravelModel({
    this.uid = '',
    this.tripName = '',
    this.designer = '',
    required this.detail,
    this.domestic = 0,
    this.city = '',
    this.country = '',
    this.tags = '',
    this.cover = ''
  });

  factory TravelModel.fromJson(Map<String, dynamic> json){
    //print(json);
    return TravelModel(
      uid: json["uid"] ?? '',
      tripName: json["tripName"] ?? '',
      domestic: json["domestic"] ?? 1,
      designer: json["designer"] ?? '',
      city: json["city"] ?? '',
      country: json["country"] ?? '',
      tags: json["tags"] ?? '',
      cover: json["cover"] ?? '',
      detail: (json["detail"] as List).map((i) => DayDetail.fromJson(i)).toList()
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "uid": uid,
      "tripName": tripName,
      "domestic": domestic,
      "designer": designer,
      "city": city,
      "country": country,
      "tags": tags,
      "cover": cover,
      "detail": detail.map((i) => i.toJson()).toList()
    };
  }
}

class AllTrip {

  final List<TravelModel> allTripList;

  AllTrip({
    required this.allTripList
  });
  
  factory AllTrip.fromJson(List json){
    return AllTrip(
      allTripList: json.map((i) => TravelModel.fromJson(i)).toList()
    );
  }
}
