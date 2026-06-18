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
  final String articleURL;
  final num width;
  final num height;
  final String articleContent;
  final num articleType;
  final List<ReturnBody> album;
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
    this.width = 0, 
    this.height = 0,
    this.articleContent = '',
    this.articleType = 1,
    required this.album,
    required this.author,
    required this.likes,
    required this.comments,
    required this.collects,
    this.articleId = '',
    this.createAt = ''
  });

  factory ArticleModel.fromJson(Map<String, dynamic> json) {
    String getAbsoluteUrl(dynamic path) {
      if (path == null) return '';
      final String sPath = path.toString().trim();
      if (sPath.isEmpty) return '';
      if (sPath.startsWith('http://') || sPath.startsWith('https://')) {
        return sPath;
      }
      return 'https://cdn.nextsticker.cn/$sPath';
    }

    return ArticleModel(
      articleName : json['articleName'] ?? '',
      picURL : getAbsoluteUrl(json['picURL']),
      videoURL : getAbsoluteUrl(json['videoURL']),
      articleURL : json['articleURL'] ?? '',
      width : json['width'] is String ? (num.tryParse(json['width']) ?? 0) : (json['width'] ?? 0),
      height : json['height'] is String ? (num.tryParse(json['height']) ?? 0) : (json['height'] ?? 0),
      articleContent : json['articleContent'] ?? '',
      articleType : json['articleType'] ?? 1,
      album : json['album'] is List ? (json['album'] as List).map((i) {
        if (i is Map<String, dynamic>) {
          final Map<String, dynamic> updatedMap = Map<String, dynamic>.from(i);
          updatedMap['key'] = getAbsoluteUrl(updatedMap['key']);
          return ReturnBody.fromJson(updatedMap);
        } else {
          return ReturnBody.fromJson(i);
        }
      }).toList() : [],
      likes : json['likes'] is List ? (json['likes'] as List).map((i) => i is Map<String, dynamic> ? AuthModel.fromJson(i) : AuthModel(uid: i.toString(), like: [], comment: [], collect: [], follow: [], followed: [])).toList() : [],
      collects : json['collects'] is List ? (json['collects'] as List).map((i) => i is Map<String, dynamic> ? AuthModel.fromJson(i) : AuthModel(uid: i.toString(), like: [], comment: [], collect: [], follow: [], followed: [])).toList() : [],
      author : json['author'] is Map<String, dynamic> ? AuthModel.fromJson(json['author']) : AuthModel(uid: json['author']?.toString() ?? '', like: [], comment: [], collect: [], follow: [], followed: []),
      comments : json['comments'] is List ? (json['comments'] as List).map((i) => Comment.fromJson(i)).toList() : [],
      articleId: json["_id"] ?? '',
      createAt: json["createAt"] ?? '',
    );
  }

  Map<String, dynamic> toJson() =>
    {
      'articleName': articleName,
      'picURL': picURL,
      'videoURL': videoURL,
      'articleURL': articleURL,
      'width': width,
      'height': height,
      'articleContent': articleContent,
      'articleType': articleType,
      'album': album,
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