import 'package:nextsticker2/model/travel_model.dart';

class ResultModel {
  final int ok;
  final int n;
  final int deletedCount;

  ResultModel({
    this.ok = 0,
    this.n = 0,
    this.deletedCount = 0,
  });

  factory ResultModel.fromJson(Map<String, dynamic> json) {
    return ResultModel(
      ok: json["ok"],
      n: json["n"],
      deletedCount: json["deletedCount"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "deletedCount": deletedCount,
      "n": n,
      "ok": ok,
    };
  }
}

class ArticleModel {
  final String articleName;
  final String picURL;
  final String videoURL;
  final String localVideoURL;
  final String localVideoThumbnailURL;
  final String articleURL;
  final num width;
  final num height;
  final String articleContent;
  final num articleType;
  final List<ReturnBody> album;
  final List<String> localURL;
  final AuthModel author;
  final List<AuthModel> likes;
  final List<AuthModel> collects;
  final List<Comment> comments;
  final String articleId;
  final String createAt;

  ArticleModel({
    this.articleName = '', 
    this.articleURL = '', 
    this.picURL = '', 
    this.videoURL = '',
    this.localVideoURL = '',
    this.localVideoThumbnailURL = '',
    this.width = 0, 
    this.height = 0,
    this.articleContent = '',
    this.articleType = 1,
    required this.album,
    required this.localURL,
    required this.author,
    required this.likes,
    required this.comments,
    required this.collects,
    this.articleId = '',
    this.createAt = ''
  });

  factory ArticleModel.fromJson(Map<String, dynamic> json) {
    //print(555555);
    // json.forEach((key, value) {
    //   print('Key: $key, Value: $value');
    // });
    return ArticleModel(
      articleName : json['articleName'],
      picURL : json['picURL'],
      videoURL : json['videoURL'] ?? '',
      localVideoURL : json['localVideoURL'] ?? '',
      localVideoThumbnailURL : json['localVideoThumbnailURL'] ?? '',
      articleURL : json['articleURL'] ?? '',
      width : json['width'],
      height : json['height'],
      articleContent : json['articleContent'] ?? '',
      articleType : json['articleType'] ?? 1,
      album : (json['album'] as List).map((i) => ReturnBody.fromJson(i)).toList(),
      localURL: (json['localURL'] as List).map((item) => item as String).toList(),
      likes : (json['likes'] as List).map((i) => AuthModel.fromJson(i)).toList(),
      collects : (json['collects'] as List).map((i) => AuthModel.fromJson(i)).toList(),
      author : json['author'] != null ? AuthModel.fromJson(json['author']) : AuthModel(like: [], comment: [], collect: [], follow: [], followed: []),
      comments : (json['comments'] as List).map((i) => Comment.fromJson(i)).toList(),
      articleId: json["_id"],
      createAt: json["createAt"],
    );
  }

  Map<String, dynamic> toJson() =>
    {
      'articleName': articleName,
      'picURL': picURL,
      'videoURL': videoURL,
      'localVideoURL': localVideoURL,
      'localVideoThumbnailURL': localVideoThumbnailURL,
      'articleURL': articleURL,
      'width': width,
      'height': height,
      'articleContent': articleContent,
      'articleType': articleType,
      'album': album,
      'localURL': localURL,
      'author': author,
      'likes': likes,
      'collects': collects,
      'comments': comments,
      "_id": articleId,
      "createAt": createAt
    };
}

class AllStoryModel {
  final List<ArticleModel> storyList;
  AllStoryModel({
    required this.storyList
  });
  factory AllStoryModel.fromJson(List json){
    return AllStoryModel(
      storyList: json.map((i) => ArticleModel.fromJson(i)).toList()
    );
  }
}