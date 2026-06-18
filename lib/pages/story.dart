import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:nextsticker2/widgets/webview.dart';
import 'package:nextsticker2/pages/micro_detail.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nextsticker2/store/store.dart';
import 'package:provider/provider.dart';
import 'package:nextsticker2/widgets/animate_edit.dart';
import 'package:nextsticker2/model/travel_model.dart';
import 'package:nextsticker2/dao/story_dao.dart';
import 'package:nextsticker2/widgets/common_image.dart';
import 'package:nextsticker2/tools/tools.dart';
import 'package:nextsticker2/tools/sync_helper.dart';

class Story extends StatefulWidget {
  final bool isActive;
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
    required this.isActive,
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

class StoryState extends State<Story> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final ScrollController _controller = ScrollController();
  int page = 2;
  int pre = 0;
  bool loading = false;
  bool showBtn = false;
  bool uploading = false;
  int _gridVersion = 0;
  
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

  void Function(String)? _syncMessageUpdater;
  void _updateSyncMessage(String msg) {
    if (_syncMessageUpdater != null) {
      _syncMessageUpdater!(msg);
    }
  }

  void _showSyncDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('数据同步选项'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('请选择要执行的数据同步操作：\n(同步范围包含本地及服务器的行程与故事列表)'),
              SizedBox(height: 10),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performSync(2); // 覆盖服务器
              },
              child: const Text('覆盖服务器数据'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performSync(3); // 覆盖本地
              },
              child: const Text('覆盖本地数据'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消', style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  void _performSync(int option) {
    String progressMessage = '正在检查数据...';
    _syncMessageUpdater = null; // 清空旧的回调
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            _syncMessageUpdater = (msg) {
              setDialogState(() {
                progressMessage = msg;
              });
            };
            return AlertDialog(
              content: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      progressMessage,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    Future.sync(() async {
      // 等待 dialog 首帧渲染完成再开始异步操作
      await Future.delayed(Duration.zero);
      try {
        // 0. 检查是否需要同步
        _updateSyncMessage('正在检查数据差异...');
        final bool syncNeeded = await SyncHelper.needsSync();
        if (!syncNeeded) {
          if (mounted) {
            Navigator.of(context).pop();
            _syncMessageUpdater = null;
            widget.openSnackBar('数据已是最新，无需同步！', 2);
          }
          return;
        }

        _updateSyncMessage('正在初始化同步...');
        // 1. Sync Trips
        await SyncHelper.syncTrips(
          option: option,
          auth: widget.auth,
          onProgress: (msg) {
            _updateSyncMessage('[行程] $msg');
          },
        );

        // 2. Sync Stories
        await SyncHelper.syncStories(
          option: option,
          auth: widget.auth,
          onProgress: (msg) {
            _updateSyncMessage('[故事] $msg');
          },
        );

        // 3. Refresh lists
        _updateSyncMessage('正在刷新本地视图数据...');
        setState(() {
          pre = 0;
          page = 2;
          _gridVersion++;
        });
        await widget.initUserData(true);

        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          _syncMessageUpdater = null;
          widget.openSnackBar('数据同步成功！', 2);
        }
      } catch (e) {
        debugPrint('Sync failed: $e');
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          widget.openSnackBar('同步失败: $e', 3);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        leading: Container(),
        title: const Text('NextSticker', style: TextStyle(color: Colors.white)),
        centerTitle:true,
      ),
      body: KeyedSubtree(
        key: ValueKey('story_body_$_gridVersion'),
        child: widget.storys.isNotEmpty
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
                    key: ValueKey('${widget.storys[index].articleId}_${widget.storys[index].picURL}_$index'),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("本地暂无故事数据", style: TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                icon: const Icon(Icons.sync, color: Colors.white,),
                label: const Text("去同步数据", style: TextStyle(color: Colors.white),),
                onPressed: _showSyncDialog,
              ),
            ],
          ),
        )
      ),
      floatingActionButton: MyAnimateEdit(
        isActive: widget.isActive,
        openSnackBar: widget.openSnackBar,
        auth: widget.auth.uid,
        platform: widget.platform,
        socket: widget.socket,
        initUserData: widget.initUserData
      )
    );
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
        if(storys[index].articleType != null && storys[index].articleType == 2 || storys[index].articleType == 3){
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
                    final bool isOnline = Provider.of<UserData>(context, listen: false).netWorkStatus;
                    if(storys[index].articleType == 3){
                      try {
                        if (isOnline) {
                          await StoryDao.deleteStoryOnServer(storys[index].articleId, [storys[index].videoURL, storys[index].picURL]);
                        }
                        await StoryDao.deleteStory(storys[index].articleId, [storys[index].videoURL, storys[index].picURL]);
                        await CommonUtils.deleteLocalFilesAsync([CommonUtils.removeBaseUrl(storys[index].picURL), CommonUtils.removeBaseUrl(storys[index].videoURL)], hasVideo: true);
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
                        if (isOnline) {
                          await StoryDao.deleteStoryOnServer(storys[index].articleId, storys[index].album.map((e) => e.key).toList());
                        }
                        await StoryDao.deleteStory(storys[index].articleId, storys[index].album.map((e) => e.key).toList());
                        await CommonUtils.deleteLocalFilesAsync(storys[index].album.map<String>((e) => CommonUtils.removeBaseUrl(e.key.toString())).toList());
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
                    color: CommonUtils.randomColor(),
                  ),
                  width: MediaQuery.of(context).size.width / 2,
                  height: (() {
                    final double w = double.tryParse(storys[index].width?.toString() ?? '') ?? 0.0;
                    final double h = double.tryParse(storys[index].height?.toString() ?? '') ?? 0.0;
                    if (w <= 0.0 || h <= 0.0) {
                      return MediaQuery.of(context).size.width / 2; // Default to 1:1 square ratio
                    }
                    double ratio = h / w;
                    if (ratio > 1.5) ratio = 1.5;
                    if (ratio < 0.5) ratio = 0.5;
                    return (MediaQuery.of(context).size.width / 2) * ratio;
                  })(),
                  child: storys[index].picURL.isEmpty
                  ? Image.asset(
                      "assets/trip_fallback.png",
                      fit: BoxFit.cover,
                    )
                  : (storys[index].articleType != null && storys[index].articleType == 2 || storys[index].articleType == 3
                      ? ImageWithFallback(
                          remoteURL: storys[index].picURL,
                          resourceId: CommonUtils.removeBaseUrl(storys[index].picURL),
                          width: MediaQuery.of(context).size.width / 2,
                          picWidth: double.tryParse(storys[index].width?.toString() ?? '') ?? 100.0,
                          picHeight: double.tryParse(storys[index].height?.toString() ?? '') ?? 100.0,
                          name: storys[index].articleName,
                        )
                      : CachedNetworkImage(
                          imageUrl: storys[index].picURL,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Image.asset(
                            "assets/trip_fallback.png",
                            fit: BoxFit.cover,
                          ),
                        )
                    ),
                ),
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
                            child: storys[index].author?.avatar != '' 
                                ? ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: storys[index].author.avatar,
                                      fit: BoxFit.cover,
                                      errorWidget: (context, url, error) => Image.asset("assets/wechat.png"),
                                    ),
                                  )
                                : ClipOval(child: Image.asset("assets/wechat.png")),
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

