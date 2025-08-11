import 'package:nextsticker2/model/travel_model.dart';

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
    //print(555555);
    //print(json['author']);
    // json.forEach((key, value) {
    //   print('Key: $key, Value: $value');
    // });
    return ArticleModel(
      articleName : json['articleName'],
      picURL : json['picURL'],
      videoURL : json['videoURL'] ?? '',
      articleURL : json['articleURL'] ?? '',
      width : json['width'],
      height : json['height'],
      articleContent : json['articleContent'] ?? '',
      articleType : json['articleType'] ?? 1,
      album : (json['album'] as List).map((i) => ReturnBody.fromJson(i)).toList(),
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