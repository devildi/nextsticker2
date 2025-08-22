import 'package:flutter/material.dart';
//import 'package:flutter_swiper/flutter_swiper.dart';
import 'package:card_swiper/card_swiper.dart';
import 'dart:math';
//import 'package:cached_network_image/cached_network_image.dart';
import 'package:nextsticker2/model/article_model.dart';
import 'package:video_player/video_player.dart';
import 'package:nextsticker2/dao/story_dao.dart';
import 'package:provider/provider.dart';
import 'package:nextsticker2/store/store.dart';
import 'package:nextsticker2/model/travel_model.dart';
import 'package:nextsticker2/widgets/common_image.dart';
import 'dart:io';
import 'package:dio/dio.dart';

class MicroDetail extends StatefulWidget {
  final ArticleModel articleFromStoryPage;
  final Function tapLike;
  final Function comment;
  final String uid;
  final int index;
  final Function openSnackBar;
  final String from;
  final Function initUserData;
  const MicroDetail({
    Key? key,
    required this.articleFromStoryPage,
    required this.tapLike,
    required this.comment,
    required this.uid,
    required this.index,
    required this.openSnackBar,
    required this.from,
    required this.initUserData,
    }): super(key: key);
  @override
  MicroDetailState createState() => MicroDetailState();
}

class MicroDetailState extends State<MicroDetail> with AutomaticKeepAliveClientMixin{
  
  @override
  bool get wantKeepAlive => true;

  late VideoPlayerController _controller;
  bool isReady = false;
  String? localVideoPath;
  late ArticleModel item;

  final TextEditingController _textController = TextEditingController();
  ScrollController controller1 = ScrollController();
  final FocusNode _focus = FocusNode();
  String content = '';

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
    item = widget.articleFromStoryPage;
    _initVideo();
  }

  Future<void> _initVideo() async {
    final url = widget.articleFromStoryPage.videoURL == '' 
      ? 'https://cdn.moji.com/websrc/video/video621.mp4' 
      : widget.articleFromStoryPage.videoURL;
    final filePath = widget.articleFromStoryPage.localVideoURL;
    final file = File(filePath);
    if (await file.exists()) {
      localVideoPath = filePath;
      _controller = VideoPlayerController.file(file);
      debugPrint('${widget.articleFromStoryPage.articleName}的本地视频存在，直接使用');
    } else {
      _controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _downloadAndSave(url, filePath);
    }
    await _controller.initialize();
    setState(() {
      isReady = true;
    });
    _controller.play();
    _controller.setLooping(true);
  }

  void toBottom(){
    if (controller1.position.maxScrollExtent != 0.0) {
      controller1.animateTo(controller1.position.maxScrollExtent + 50,
        duration: const Duration(milliseconds: 200),
        curve: Curves.ease
      );
    }   
  }

  Future<void> _downloadAndSave(String url, String savePath) async {
    try {
      Dio dio = Dio();
      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            debugPrint("下载进度: ${(received / total * 100).toStringAsFixed(0)}%");
          }
        },
      );
      debugPrint("视频已缓存到: $savePath");
    } catch (e) {
      debugPrint("下载视频失败: $e");
    }
  }

  void _onFocusChange() {
    //debugPrint("Focus: ${_focus.hasFocus.toString()}");
    AuthModel auth = Provider.of<UserData>(context, listen: false).auth;
    if(auth.uid == '' && _focus.hasFocus){
      _focus.unfocus();
      Navigator.pushNamed(context, "login", arguments: {
        "fn": widget.openSnackBar,
        "initUserData": widget.initUserData
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
  }

  void fedback(str){
    debugPrint(str);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: Colors.blue, content: Text('感谢反馈！', textAlign: TextAlign.center)),
    );
  }

  Future<void> _show() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        String character = '引人不适';
        return AlertDialog(
          title: const Text('问题反馈：'),
          content: StatefulBuilder(builder: (context, StateSetter setState) {
            return SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  ListTile(
                    title: const Text('引人不适'),
                    leading: Radio(
                      value: '引人不适',
                      groupValue: character,
                      onChanged: (value){
                        setState(() {
                          character = value as String;
                        });
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('内容质量较差'),
                    leading: Radio(
                      value: '内容质量较差',
                      groupValue: character,
                      onChanged: (value){
                        setState(() {
                          character = value as String;
                        });
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('过期内容'),
                    leading: Radio(
                      value: '过期内容',
                      groupValue: character,
                      onChanged: (value){
                        setState(() {
                          character = value as String;
                        });
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('标题党封面党'),
                    leading: Radio(
                      value: '标题党封面党',
                      groupValue: character,
                      onChanged: (value){
                        setState(() {
                          character = value as String;
                        });
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
          actions: <Widget>[
            TextButton(
              child: const Text('提交反馈'),
              onPressed: () {
                Navigator.of(context).pop();
                fedback(character);
              },
            ),
          ],
        );
      },
    );
  }
  
  Widget containerPic(imgs, width, height, type){
    if(type == 3){
      return
        Container(
          width: MediaQuery.of(context).size.width - 40, 
          height: (MediaQuery.of(context).size.width - 40) / width * height,
          margin: const EdgeInsets.fromLTRB(0, 0, 5, 0),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            color: randomColor(),
          ),
          child: isReady
            ?AspectRatio(
              aspectRatio: width / height,
              child: VideoPlayer(_controller),
            )
            :const Center(
              child: CircularProgressIndicator(),
            )
        );
    }
    if(imgs.length == 1){
      return
        Container(
          width: MediaQuery.of(context).size.width,
          height:MediaQuery.of(context).size.width * height / width,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: randomColor(),
          ),
          child: 
          ImageWithFallback(
            remoteURL: widget.articleFromStoryPage.picURL,
            localURL: widget.articleFromStoryPage.localURL[0],
            width: widget.articleFromStoryPage.width.toDouble(),
            picWidth: widget.articleFromStoryPage.width.toDouble(),
            picHeight: widget.articleFromStoryPage.height.toDouble(),
            name: widget.articleFromStoryPage.articleName
          )
          // CachedNetworkImage(
          //   imageUrl: imgs[0].key,
          //   fit: BoxFit.cover
          // ),
        );
    } else {
      return 
        Container(
          height: MediaQuery.of(context).size.width * height / width,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Swiper(
            itemBuilder: (BuildContext context,int index){
                return
                  Container(
                    width: MediaQuery.of(context).size.width / 2,
                    height: MediaQuery.of(context).size.height * height / width,
                    decoration: BoxDecoration(
                      color: randomColor(),
                    ),
                    child: 
                    ImageWithFallback(
                      remoteURL: imgs[index].key,
                      localURL: widget.articleFromStoryPage.localURL[index],
                      width: widget.articleFromStoryPage.width.toDouble(),
                      picWidth: widget.articleFromStoryPage.width.toDouble(),
                      picHeight: widget.articleFromStoryPage.height.toDouble(),
                      name: widget.articleFromStoryPage.articleName
                    )
                    // CachedNetworkImage(
                    //   imageUrl: imgs[index].key,
                    //   fit: BoxFit.cover
                    // ),
                  );
            },
            itemCount: imgs.length,
            pagination: const SwiperPagination(),
          ),
        );
    }
  }

  void _onChanged(String str){
    setState((){
      content = str;
    });
  }

  void _onSubmitted(str) async{
    AuthModel auth = Provider.of<UserData>(context, listen: false).auth;
    await widget.comment(str, auth.uid ,widget.articleFromStoryPage.articleId, widget.index, widget.initUserData);
    _textController.text = '';
    try{
      ArticleModel res = await StoryDao.getStoryByID(widget.articleFromStoryPage.articleId);
      setState(() {
        item = res;
      });
      toBottom();
    }catch(err){
      debugPrint(err.toString());
    }
  }

  List<Widget> _comments(array){
    if(array.length > 0){
      final List fixedList = Iterable<int>.generate(array.length).toList();
      List <Widget>commentArray = [];
      fixedList.asMap().forEach((i, item){
        commentArray.add(_conmentItem(array[i]));
      });
      return commentArray;
    } else {
        return [Container()];
      }
  }

  Widget _conmentItem (i) {
    return Padding(
      padding: const EdgeInsets.all(3.0),
      child: 
        Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipOval(
            child: Container(
              color: Colors.blue,
              width: 40,
              height: 40,
              child: i.whoseContent.avatar != '' ? ClipOval(child: Image.network(i.whoseContent.avatar)) : ClipOval(child: Image.asset("assets/wechat.png"))
            )
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(15, 0, 0, 5),
                  child: Text(i.whoseContent.name, style: const TextStyle(fontSize: 15, color: Colors.grey)),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(15, 0, 0, 5),
                  child: Text(i.content),
                ),
              ],
            )
          )
        ],
      ));
  }

  void likeInDetail(uid, articleId, type, index) async{
    if(uid != null){
      await widget.tapLike(uid, articleId, type, index, widget.from == 'myPo' ? true : false);
      try{
        ArticleModel res = await StoryDao.getStoryByID(articleId);
        setState(() {
          item = res;
        });
      }catch(err){
        debugPrint(err.toString());
      }
    } else {
      debugPrint('请登录：');
      Navigator.pushNamed(context, "login", arguments: {
        "fn": widget.openSnackBar,
        "initUserData": widget.initUserData
      }).then((value ) => {
        debugPrint(value.toString())
      });
    }
  } 

  bool likeOrNot(array, uid){
    bool result = false;
    array.forEach((row){
      if(row.uid == uid){
        result = true;
      }
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    AuthModel auth = Provider.of<UserData>(context).auth;
    return Scaffold(
      appBar: AppBar(
        title: const Text('故事'),
        centerTitle:true,
        actions:<Widget>[
          TextButton(
            onPressed: _show,
            child: const Text('内容反馈', style: TextStyle(color: Colors.black)),
          )
        ]
      ),
      body: 
      Stack(
        children: [
          Container(
            width: MediaQuery.of(context).size.width,
            margin: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 50),
            decoration: const BoxDecoration(
              //color: Color.fromARGB(255, 218, 208, 208), 
            ),
            child: ListView(
              controller: controller1,
              //crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              containerPic(widget.articleFromStoryPage.album, widget.articleFromStoryPage.width, widget.articleFromStoryPage.height, widget.articleFromStoryPage.articleType),
              Container(
                margin: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                child: Text(widget.articleFromStoryPage.articleName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              Text(widget.articleFromStoryPage.articleContent, style: const TextStyle(fontSize: 15)),
              Container(
                margin: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                child: Text("${widget.articleFromStoryPage.createAt.substring(0, 10)} 发布", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w200)),
              ),
              const Divider(),
              ..._comments(getObj(item, widget.articleFromStoryPage).comments)
            ]),
            
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              width: MediaQuery.of(context).size.width,
              padding: EdgeInsets.fromLTRB(10, 5, 5, MediaQuery.of(context).padding.bottom + 5),
              decoration: const BoxDecoration(
                color: Colors.white
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextField(
                      autofocus: false,
                      focusNode: _focus,
                      onSubmitted: _onSubmitted,
                      onChanged: _onChanged,
                      controller: _textController,
                      decoration: const InputDecoration(
                        fillColor: Color.fromARGB(238, 204, 204, 204),
                        filled: true,
                        hintText: '说点什么吧~',
                        contentPadding: EdgeInsets.fromLTRB(10, 0, 0, 0),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0x00FF0000)),
                          borderRadius: BorderRadius.all(Radius.circular(25))),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0x00000000)),
                          borderRadius: BorderRadius.all(Radius.circular(25))),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => likeInDetail(auth.uid, widget.articleFromStoryPage.articleId, 'like', widget.index),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
                      child: likeOrNot(getObj(item, widget.articleFromStoryPage).likes, auth.uid) ? const Icon(Icons.favorite, color: Colors.redAccent, size: 35) : const Icon(Icons.favorite_border, color: Colors.black, size: 35),
                    ),
                  ),
                  getObj(item, widget.articleFromStoryPage).likes.isNotEmpty ? Text("${getObj(item, widget.articleFromStoryPage).likes.length}") : Container(),
                  GestureDetector(
                    onTap: () => likeInDetail(auth.uid, widget.articleFromStoryPage.articleId, 'collect', widget.index),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
                      child:  likeOrNot(getObj(item, widget.articleFromStoryPage).collects, auth.uid) ? const Icon(Icons.star, color: Colors.orange, size: 37) : const Icon(Icons.star_border, color: Colors.black, size: 37,),
                    ),
                  ),
                  getObj(item, widget.articleFromStoryPage).collects.isNotEmpty ? Text("${getObj(item, widget.articleFromStoryPage).collects.length}") : Container(),
                ],
              ),
            ),
          )
        ],
      )
    );
  }
}

Color randomColor(){
  List colors = [Colors.red[100], Colors.green[100], Colors.yellow[100], Colors.orange[100]];
  Random random = Random();
  return colors[random.nextInt(4)];
}

ArticleModel getObj(item, item2){
  if(item != null){
    return item;
  } else {
    return item2;
  }
}