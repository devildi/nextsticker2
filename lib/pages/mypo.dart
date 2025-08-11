import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nextsticker2/pages/micro_detail.dart';
import 'package:nextsticker2/widgets/webview.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:nextsticker2/model/travel_model.dart';
import 'package:provider/provider.dart';
import 'package:nextsticker2/store/store.dart';
import 'package:flutter/foundation.dart';

class MyPo extends StatefulWidget {
  final List storys;
  final AuthModel auth;
  final Function tapLike;
  final Function comment;
  final dynamic platform;
  final Function getMore;
  final Function openSnackBar;
  final String flag;
  final bool netWorkIsOn;
  const MyPo({
    Key? key,
    required this.storys,
    required this.auth,
    required this.tapLike,
    required this.comment,
    required this.platform,
    required this.getMore,
    required this.openSnackBar,
    required this.flag,
    required this.netWorkIsOn
    }): super(key: key);
  @override
  MyPoState createState() => MyPoState();
}

class MyPoState extends State<MyPo> {
  final ScrollController _controller = ScrollController();
  bool loading = false;
  int page = 2;
  int pre = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
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
  }

  Future <void> _addMoreData(index) async{
    if(loading == false){
      setState(() {
        loading = true;
        getMore(index);
      });
    }
  }

  void getMore(index)async{
    if(loading == true){
      await widget.getMore(widget.flag, Provider.of<UserData>(context, listen: false).auth.uid, index);
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
  Widget build(BuildContext context) {
    List trips = Provider.of<UserData>(context).trips;
    bool loading = Provider.of<UserData>(context).loading;

    return Scaffold(
      body: widget.storys.isNotEmpty
      ?MasonryGridView.count(
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
              tapLike: widget.tapLike,
              comment: widget.comment,
              uid: widget.auth.uid,
              platform: widget.platform,
              openSnackBar: widget.openSnackBar
            );
        },
      )
      :Center(
        child: trips.isNotEmpty && !loading || !widget.netWorkIsOn
        ? const Text("无内容！") 
        : const CircularProgressIndicator()
      )
    );
  }
}

class _Item extends StatelessWidget {
  final int index;
  final List storys;
  final Function tapLike;
  final String uid;
  final Function comment;
  final dynamic platform;
  final Function openSnackBar;
  const _Item({
    Key? key,
    required this.index, 
    required this.storys, 
    required this.tapLike,
    required this.uid,
    required this.comment,
    required this.platform,
    required this.openSnackBar,
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
              from: 'myPo',
              initUserData: () {},
            )
          ));
        } else {
          Navigator.push(context, MaterialPageRoute(
            //url: '${storys[index].articleURL}'
            builder: (context) => WebViewExample(url: '${storys[index].articleURL}')
          ));
        }
      },
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
                    child: CachedNetworkImage(
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
                            storys[index].author != null && storys[index].author.name != null ? Text(storys[index].author.name) : const Text('DevilDI')
                          ],
                        ),
                        Row(
                          mainAxisAlignment:MainAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () => tapLike(uid, storys[index].articleId, 'like', index, true),
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
            ],
          )
          
        )
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