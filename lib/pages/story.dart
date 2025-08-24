import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:nextsticker2/widgets/webview.dart';
import 'package:nextsticker2/pages/micro_detail.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math';
import 'package:nextsticker2/store/store.dart';
import 'package:provider/provider.dart';
import 'package:nextsticker2/widgets/animate_edit.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:nextsticker2/model/travel_model.dart';
import 'package:nextsticker2/dao/story_dao.dart';
import 'package:flutter/foundation.dart';
import 'package:nextsticker2/widgets/common_image.dart';
import 'package:nextsticker2/tools/tools.dart';

class Story extends StatefulWidget {
  final List storys;
  final Function onRefresh;
  final Function getMore;
  final bool netWorkIsOn;
  final Function reFresh;
  final Function openSnackBar;
  final AuthModel auth;
  final dynamic platform;
  final dynamic socket;
  final Function tapLike;
  final Function comment;
  final Function initUserData;
  const Story({
    Key? key,
    required this.storys,
    required this.onRefresh, 
    required this.getMore,
    required this.netWorkIsOn,
    required this.reFresh,
    required this.openSnackBar,
    required this.auth,
    required this.platform,
    required this.socket,
    required this.tapLike,
    required this.comment,
    required this.initUserData
    }): super(key: key);
  @override
  StoryState createState() => StoryState();
}

class StoryState extends State<Story> {
  final ScrollController _controller = ScrollController();
  int page = 2;
  int pre = 0;
  bool loading = false;
  bool showBtn = false;
  bool uploading = false;
  
  Future <void>_onRefresh() async{
    await widget.onRefresh();
    setState(() {
      pre = 0;
      page = 2;
    });
  }

  Future <void> _addMoreData(index) async{
    if(loading == false){
      setState(() {
        loading = true;
        getMore(index);
      });
    }
  }

  void _refresh(){
    widget.reFresh();
  }

  void toTop(){
    _controller.animateTo(.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.ease
    );
    //_onRefresh();
  }

  void upToServer(body, fn, title, content) async{
    List picArr = [];
    for (var i = 0; i < body.length; i++) {
      picArr.add(body[i].toJson());
    }
    try{
      dynamic res = await StoryDao.poMicro({
        'articleName': title,
        'articleContent': content,
        'picURL': body[0].key,
        'width': body[0].width,
        'height': body[0].height,
        'articleType': 2,
        'album': picArr
      });
      if(res != null){
        setState(() {
          uploading = false;
          Navigator.of(context).pop();
          fn('发布成功！请下拉刷新！', 2);
        });
      }
    }catch(err){
      debugPrint(err.toString());
      setState(() {
        uploading = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.blue, content: Text('网络错误，发布失败！', textAlign: TextAlign.center)),
        );
      });
    }
  }

  void getMore(index)async{
    if(loading == true){
      await widget.getMore("STORY", index);
      if (!context.mounted) return;
      if(Provider.of<UserData>(context, listen: false).netWorkStatus){
        setState(() {
          loading = false;
          pre = widget.storys.length;
          page = index + 1;
        });
      } else {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (_controller.offset < 1000 && showBtn) {
        setState(() {
          showBtn = false;
        });
      } else if (_controller.offset >= 1000 && showBtn == false) {
        setState(() {
          showBtn = true;
        });
      }
      if (_controller.position.pixels == _controller.position.maxScrollExtent) {
        if(widget.storys.length - pre == 20){
          _addMoreData(page);
        } else if(!Provider.of<UserData>(context, listen: false).netWorkStatus){
          _addMoreData(page);
        }
      }
    });
  }
  
  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //super.build(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        leading: Container(),
        //leading:GestureDetector(child: Image.asset("assets/chatgpt.png"), onTap: () => {debugPrint('chatgpt')}),
        title: const Text('NextSticker', style: TextStyle(color: Colors.white)),
        centerTitle:true,
      ),
      body: (widget.storys.isNotEmpty
      ? Stack(
        children: [
          RefreshIndicator(
            onRefresh: _onRefresh,
            child: MasonryGridView.count(
              controller: _controller,
              crossAxisCount: 2,
              mainAxisSpacing: 1,
              crossAxisSpacing: 1,
              itemCount: widget.storys.length,
              itemBuilder: (context, index) {
                return 
                  _Item(
                    index: index, 
                    storys: widget.storys,
                    platform: widget.platform,
                    tapLike: widget.tapLike,
                    comment: widget.comment,
                    uid: widget.auth.uid,
                    openSnackBar: widget.openSnackBar,
                    initUserData: widget.initUserData,
                  );
              },
            )
          ),
          loading == true
          ?const Center(
            child: CircularProgressIndicator(),
          )
          :Container()
        ],
      )
      : Center(
          child: widget.netWorkIsOn 
          ? const CircularProgressIndicator() 
          : ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            icon: const Icon(Icons.refresh, color: Colors.white,),
            label: const Text("点击刷新",style: TextStyle(color: Colors.white),),
            onPressed: _refresh,
          )
        )
      ),
      floatingActionButton: MyAnimateEdit(
        openSnackBar: widget.openSnackBar,
        auth: widget.auth.uid,
        platform: widget.platform,
        socket: widget.socket,
        initUserData: widget.initUserData
      )
    );
  }
}

Color randomColor(){
  List colors = [Colors.red[100], Colors.green[100], Colors.yellow[100], Colors.orange[100]];
  Random random = Random();
  return colors[random.nextInt(4)];
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

class _Item extends StatelessWidget {
  final int index;
  final List storys;
  final dynamic platform;
  final Function tapLike;
  final String uid;
  final Function comment;
  final Function openSnackBar;
  final Function initUserData;
  const _Item({
    Key? key,
    required this.index, 
    required this.storys, 
    required this.platform,
    required this.tapLike,
    required this.uid,
    required this.comment,
    required this.openSnackBar,
    required this.initUserData,
  }): super(key: key);
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (){
        if( storys[index].articleType != null && storys[index].articleType == 2 || storys[index].articleType == 3){
          Navigator.push(context, MaterialPageRoute(
            //url: '${storys[index].articleURL}'
            builder: (context) => MicroDetail(
              articleFromStoryPage: storys[index],
              tapLike: tapLike,
              comment: comment,
              uid: uid,
              index: index,
              openSnackBar: openSnackBar,
              from: '',
              initUserData: initUserData
            )
          ));
        } else {
          Navigator.push(context, MaterialPageRoute(
            //url: '${storys[index].articleURL}'
            builder: (context) => WebViewExample(url: '${storys[index].articleURL}')
          ));
        }
      },
      onLongPress: (){if(storys[index].author.name == Provider.of<UserData>(context, listen: false).auth.name){
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('删除'),
              content: const Text('是否删除该内容？'),
              actions: <Widget>[
                TextButton(
                  child: const Text('取消'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: const Text('确定'),
                  onPressed: () async{
                    if(storys[index].articleType == 3){
                      try {
                        await StoryDao.deleteStory(storys[index].articleId, [storys[index].videoURL, storys[index].picURL]);
                        CommonUtils.deleteLocalFilesAsync([storys[index].localVideoURL, storys[index].localVideoThumbnailURL]);
                        initUserData(true);
                        openSnackBar('已删除！', 1);
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      } catch (e) {
                        debugPrint(e.toString());
                        openSnackBar('网络错误，删除失败！', 1);
                      }
                    } else if(storys[index].articleType == 2) {
                       try {
                        await StoryDao.deleteStory(storys[index].articleId, storys[index].album.map((e) => e.key).toList());
                        CommonUtils.deleteLocalFilesAsync(storys[index].album.map((e) => e.key.toString()).toList());
                        initUserData(true);
                        openSnackBar('已删除！', 1);
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      } catch (e) {
                        debugPrint(e.toString());
                        openSnackBar('网络错误，删除失败！', 1);
                      }
                    }
                  },
                )
              ],
            );
          }
        );
      }},
      child: Card(
        child: PhysicalModel(
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(2),
          child: Stack(
            children: [
              Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container( 
                  decoration: BoxDecoration(
                    color: randomColor(),
                  ),
                  width: MediaQuery.of(context).size.width / 2,
                  height: (MediaQuery.of(context).size.width / 2) * storys[index].height / storys[index].width,
                  child: storys[index].articleType != null && storys[index].articleType == 2 || storys[index].articleType == 3
                  // ?CachedNetworkImage(
                  //   imageUrl: storys[index].picURL,
                  //   fit: BoxFit.cover,
                  // )
                  ?ImageWithFallback(
                    remoteURL: storys[index].picURL,
                    resourceId: CommonUtils.removeBaseUrl(storys[index].picURL),
                    width: storys[index].width.toDouble(),
                    picWidth: storys[index].width.toDouble(),
                    picHeight: storys[index].height.toDouble(),
                    name: storys[index].articleName
                  )
                  :CachedNetworkImage(
                    imageUrl: storys[index].picURL,
                    fit: BoxFit.cover,
                  ),
                ),
                //Picture(url: storys[index].picURL),
                //Image.network(storys[index].picURL),
                Container(
                  padding: const EdgeInsets.all(7),
                  child: Text('${storys[index].articleName}',style: const TextStyle(fontSize: 15)),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
                  child: Row(
                    mainAxisAlignment:MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment:MainAxisAlignment.start,
                        children: [
                          Container(
                            height: 20,
                            width: 20,
                            margin: const EdgeInsets.fromLTRB(0, 0, 7, 3),
                            child: storys[index].author?.avatar != '' ? ClipOval(child: Image.network(storys[index].author.avatar)) : ClipOval(child: Image.asset("assets/wechat.png")),
                          ),
                          storys[index].author != null && storys[index].author.name != '' ? Text(storys[index].author.name) : const Text('DevilDI', style: TextStyle(color: Colors.black),)
                        ],
                      ),
                      Row(
                        mainAxisAlignment:MainAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => tapLike(uid, storys[index].articleId, 'like', index, false),
                            child: Container(
                              height: 20,
                              width: 20,
                              margin: const EdgeInsets.fromLTRB(0, 0, 7, 3),
                              child: likeOrNot(storys[index].likes, uid) ? const Icon(Icons.favorite, color: Colors.redAccent) : const Icon(Icons.favorite_border, color: Colors.grey),
                            ),
                          ),
                          storys[index].likes.length > 0 ? Text("${storys[index].likes.length}") : Container()
                        ],
                      ),
                    ],
                  )
                ),
              ],
            ),
            storys[index].articleType == 3
            ?const Positioned(
              top: 4,
              right: 4,
              child: Icon(Icons.play_circle_outline, color: Colors.white,),
            )
            :Container()
          ],)
        )
      )
    );
  }
}

class VideoContainer extends StatefulWidget {
  final String url;
  final dynamic platform;
  const VideoContainer({
    Key? key,
    required this.url, 
    required this.platform, 
    }): super(key: key);
  @override
  VideoContainerState createState() => VideoContainerState();
}

class VideoContainerState extends State<VideoContainer> {
  dynamic data;
  @override
  void initState() {
    super.initState();
    if(defaultTargetPlatform == TargetPlatform.iOS){
      getPoster(widget.url);
    } else {
      getPoster(widget.url);
    }
  }

  Future getPoster(url)async{
    try{
      final uint8list = await VideoThumbnail.thumbnailData(
        video: url,
        imageFormat: ImageFormat.JPEG,
        quality: 25,
      );
      setState(() {
        data = uint8list;
      });
    }catch(err){
      debugPrint(err.toString());
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return
      Container(
        child: data != null
          ?Image.memory(data, fit: BoxFit.cover)
          :const Center(
            child: CircularProgressIndicator(),
          )
      );
  }
}

class Picture extends StatelessWidget {
  final String url;
  const Picture({
    Key? key,
    required this.url, 
  }): super(key: key);

  Future<ui.Image> _getImage(url) {
    Completer<ui.Image> completer = Completer<ui.Image>();
    NetworkImage(url)
      .resolve(const ImageConfiguration())
      .addListener(ImageStreamListener((ImageInfo info, bool _) {
        completer.complete(info.image);
      }));
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return 
      FutureBuilder<ui.Image>(
        future: _getImage(url),
        builder: (BuildContext context, AsyncSnapshot<ui.Image> snapshot) {
          if (snapshot.hasData) {
            ui.Image image = snapshot.data!;
            return 
              SizedBox(
                width: MediaQuery.of(context).size.width / 2,
                height: (MediaQuery.of(context).size.width / 2) * image.height / image.width,
                child: Image.network(url),
              );
          } else {
            return Container();
          }
        },
      );
    }
}