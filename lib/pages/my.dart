import 'package:flutter/material.dart';
import 'package:nextsticker2/model/travel_model.dart';
import 'package:nextsticker2/pages/mypo.dart';
//import 'package:nextsticker2/pages/tool.dart';
import 'package:nextsticker2/pages/diy.dart';
import 'package:provider/provider.dart';
import 'package:nextsticker2/store/store.dart';
import 'package:nextsticker2/pages/map_design.dart';
import 'package:uuid/uuid.dart';
import 'package:nextsticker2/tools/sync_helper.dart';

class Myself extends StatefulWidget {
  final Function openSnackBar;
  final AuthModel auth;
  final Function logout;
  final List storyListAuthor;
  final List storyListLikes;
  final List storyListCollects;
  final Function tapLike;
  final Function comment;
  final dynamic platform;
  final Function getMore;
  final Function initUserData;
  final bool netWorkIsOn;
  final Function setTripData;
  final Function getMoreTripData;
  final Function onRefresh;
  const Myself({
    Key? key,
    required this.openSnackBar,
    required this.auth,
    required this.logout,
    required this.storyListCollects,
    required this.storyListAuthor,
    required this.storyListLikes,
    required this.tapLike,
    required this.comment,
    required this.platform,
    required this.getMore,
    required this.initUserData,
    required this.netWorkIsOn,
    required this.setTripData,
    required this.getMoreTripData,
    required this.onRefresh
  }): super(key: key);
  @override
  MyselfState createState() => MyselfState();
}

class MyselfState extends State<Myself> with TickerProviderStateMixin {
  late TabController _tabController;
  final uuid = const Uuid();
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _jumpToToolPage(){
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => Diy(
        platform: widget.platform,
        setTripData: widget.setTripData,
        getMore: widget.getMoreTripData
      )
    ));
  }

  void _changeAvata(){

  }

  void _logon(){
    Navigator.pushNamed(context, "login", arguments: {
      "fn": widget.openSnackBar,
      "initUserData": widget.initUserData
    });
  }

  void _logout(){
    widget.logout();
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
                _performSync(2);
              },
              child: const Text('覆盖服务器数据'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performSync(3);
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
    _syncMessageUpdater = null; // 清空旧的回调，防止指向已销毁的 dialog

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
      // 等待 dialog 首帧渲染完成（StatefulBuilder 完成赋值）再开始异步操作
      await Future.delayed(Duration.zero);
      final AuthModel user = Provider.of<UserData>(context, listen: false).auth;
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
        await SyncHelper.syncTrips(
          option: option,
          auth: user,
          onProgress: (msg) {
            _updateSyncMessage('[行程] $msg');
          },
        );

        await SyncHelper.syncStories(
          option: option,
          auth: user,
          onProgress: (msg) {
            _updateSyncMessage('[故事] $msg');
          },
        );

        _updateSyncMessage('正在刷新本地视图数据...');
        await widget.onRefresh();
        await widget.initUserData(true);

        if (mounted) {
          Navigator.of(context).pop();
          _syncMessageUpdater = null;
          widget.openSnackBar('数据同步成功！', 2);
        }
      } catch (e) {
        debugPrint('Sync failed: $e');
        if (mounted) {
          Navigator.of(context).pop();
          _syncMessageUpdater = null;
          widget.openSnackBar('同步失败: $e', 3);
        }
      }
    });
  }

  void _jump(user){
    //行程初始化模版
    TravelModel trip = TravelModel(
      designer: user.name,
      uid: uuid.v4(),
      detail: [DayDetail(dayList: [])],
      domestic: 1,
    );
    Provider.of<UserData>(context, listen: false).setCloneData(trip);
    //debugPrint(trip.toJson().toString());
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => MapDesign(
        platform: widget.platform,
        tripData: trip,
        setTripData: widget.setTripData,
        onRefreshList: widget.onRefresh
      )
    ));
  }

  @override
  Widget build(BuildContext context) {
    AuthModel user = Provider.of<UserData>(context).auth;
    return Scaffold(
      body: Stack(children: [
        Column(
        children: <Widget>[
          SizedBox(
            // Stack 高度 = 蓝色区域高度 + 卡片露出部分(50px)
            height: MediaQuery.of(context).size.height / 2 - 200 + 50,
            child: Stack(
              children: [
                // 蓝色 header（原始高度不变）
                Positioned(
                  top: 0, left: 0, right: 0,
                  height: MediaQuery.of(context).size.height / 2 - 200,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(15, 0, 15, 0),
                    color: Colors.blue,
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _changeAvata,
                          child: SizedBox(
                            width: 60,
                            height: 60,
                            child: ClipOval(child: widget.auth.avatar != '' ? Image.network(widget.auth.avatar) : Image.asset("assets/wechat.png")),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            widget.auth.name != ''
                            ?Row(
                              children: [
                                GestureDetector(
                                  onTap: _changeAvata,
                                  child: Container(
                                    padding: const EdgeInsets.only(left: 20),
                                    child: Text(widget.auth.name, style: const TextStyle(color: Colors.white, fontSize: 25),),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                GestureDetector(
                                  onTap: _showSyncDialog,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.white70),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: const Text('同步数据', style: TextStyle(color: Colors.white, fontSize: 13)),
                                  ),
                                ),
                              ],
                            )
                            :Row(
                              children: [
                                GestureDetector(
                                  onTap: _logon,
                                  child: Container(
                                    padding: const EdgeInsets.only(left: 20),
                                    child: const Text('登录 | 注册',style: TextStyle(color: Colors.white, fontSize: 25),),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                GestureDetector(
                                  onTap: _showSyncDialog,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.white70),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: const Text('同步数据', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: _jumpToToolPage,
                              child: Container(
                                padding: const EdgeInsets.only(left: 20),
                                child: const Text('NextSticker | 行程列表',style: TextStyle(color: Colors.white, fontSize: 15),),
                              ),
                            ),
                          ]
                        )
                      ],
                    ),
                  ),
                ),
                // 白色卡片固定在 Stack 底部，顶部 50px 叠入蓝色区域
                Positioned(
                  bottom: 0, left: 10, right: 10,
                  height: 100,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          offset: Offset(15.0, 15.0),
                          blurRadius: 15.0,
                          spreadRadius: 1.0
                        )
                      ]
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12.0, top: 12.0, bottom: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: widget.auth.name != '' ? () => _jump(user) : _logon,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.send, color: Colors.white, size: 32),
                                ),
                                const Text(
                                  "定制",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black54,
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => widget.openSnackBar('火车票服务暂未开放', 2),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.teal,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.train, color: Colors.white, size: 32),
                                ),
                                const Text(
                                  "火车票",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black54,
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => widget.openSnackBar('飞机票服务暂未开放', 2),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.flight, color: Colors.white, size: 32),
                                ),
                                const Text(
                                  "飞机票",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black54,
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicator: const BoxDecoration(),
            indicatorWeight: 0,
            tabs: const <Widget>[
              Tab(text: "发布"),
              Tab(text: "点赞"),
              Tab(text: "收藏"),
            ],
          ),
          Expanded(
            flex: 1,
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                widget.auth.name != ''
                ? MyPo(
                    storys: widget.storyListAuthor,
                    auth: widget.auth,
                    tapLike: widget.tapLike,
                    comment: widget.comment,
                    platform: widget.platform,
                    getMore: widget.getMore,
                    openSnackBar: widget.openSnackBar,
                    flag: "author",
                    netWorkIsOn: widget.netWorkIsOn
                  )
                :Center(
                  child: GestureDetector(
                    onTap: _logon,
                    child: const Text("去登录"),
                  )
                ),
                widget.auth.name != ''
                ? MyPo(
                    storys: widget.storyListLikes,
                    auth: widget.auth,
                    tapLike: widget.tapLike,
                    comment: widget.comment,
                    platform: widget.platform,
                    getMore: widget.getMore,
                    openSnackBar: widget.openSnackBar,
                    flag: "likes",
                    netWorkIsOn: widget.netWorkIsOn
                  )
                :Center(
                  child: GestureDetector(
                    onTap: _logon,
                    child: const Text("去登录"),
                  )
                ),
                widget.auth.name != ''
                ? MyPo(
                    storys: widget.storyListCollects,
                    auth: widget.auth,
                    tapLike: widget.tapLike,
                    comment: widget.comment,
                    platform: widget.platform,
                    getMore: widget.getMore,
                    openSnackBar: widget.openSnackBar,
                    flag: "comments",
                    netWorkIsOn: widget.netWorkIsOn
                  )
                :Center(
                  child: GestureDetector(
                    onTap: _logon,
                    child: const Text("去登录"),
                  )
                ),
              ],
            ),
          )          
        ]
      ),
      widget.auth.name != ''
      ?Positioned(
        right: 20,
        top: MediaQuery.of(context).padding.top + 20,
        child: GestureDetector(
          onTap: _logout,
          child: const Text('登出', style: TextStyle(color: Colors.white, fontSize: 15)),
        ),
      )
      :Container(),
      ],
      )
    );
  }
}