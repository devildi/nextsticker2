import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nextsticker2/pages/map_design.dart';
import 'package:provider/provider.dart';
import 'package:nextsticker2/store/store.dart';
import 'package:nextsticker2/model/travel_model.dart';
import 'package:nextsticker2/dao/travel_dao.dart';
import 'package:nextsticker2/tools/sync_helper.dart';

class Diy extends StatefulWidget {
  final dynamic platform;
  final Function setTripData;
  final Function getMore;
  const Diy({
    Key? key,
    required this.platform,
    required this.setTripData,
    required this.getMore,
    }): super(key: key);
  @override
  DiyState createState() => DiyState();
}

class DiyState extends State<Diy> {
  int page = 2;
  int pre = 0;
  final ScrollController _controller = ScrollController();
  bool loading = false;
  final Set<String> _failedImages = {};

  void _handleImageError(dynamic trip) async {
    final bool isCover = trip.cover != '';
    final String nameOfScence = (trip.detail.isNotEmpty && trip.detail[0].dayList.isNotEmpty)
        ? trip.detail[0].dayList[0].nameOfScence
        : '';
    final String queryKey = '${trip.uid}_${isCover ? "cover" : nameOfScence}';
    
    if (_failedImages.contains(queryKey)) return;
    _failedImages.add(queryKey);
    
    final String searchName = isCover ? (trip.city != '' ? trip.city : nameOfScence) : nameOfScence;
    if (searchName.isEmpty) return;

    debugPrint('检测到图片链接失效，正在请求后台更新: $searchName');
    String newUrl = await TravelDao.handleImageFailure(
      uid: trip.uid,
      tripName: trip.tripName,
      nameOfScence: searchName,
      isCover: isCover,
    );
    
    if (newUrl.isNotEmpty) {
      debugPrint('后台图片已更新: $newUrl');
      if (mounted) {
        setState(() {
          if (isCover) {
            trip.cover = newUrl;
          } else {
            trip.detail[0].dayList[0].picURL = newUrl;
          }
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (_controller.position.pixels == _controller.position.maxScrollExtent) {
        if(Provider.of<UserData>(context, listen: false).trips.length - pre == 20){
          debugPrint('开始加载更多数据');
          _addMoreData(page);
        }else if(!Provider.of<UserData>(context, listen: false).netWorkStatus){
          _addMoreData(page);
        }
      }
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

  void getMore(index) async{
    if(loading == true){
      //print(index);
      await widget.getMore("LIST", index);
      if (!context.mounted) return;
      if(Provider.of<UserData>(context, listen: false).netWorkStatus){
        setState(() {
          loading = false;
          pre = Provider.of<UserData>(context, listen: false).trips.length;
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
      final UserData userData = Provider.of<UserData>(context, listen: false);
      final AuthModel user = userData.auth;
      try {
        // 0. 检查是否需要同步
        _updateSyncMessage('正在检查数据差异...');
        final bool syncNeeded = await SyncHelper.needsSync();
        if (!syncNeeded) {
          if (mounted) {
            Navigator.of(context).pop();
            _syncMessageUpdater = null;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(backgroundColor: Colors.blue, content: Text('数据已是最新，无需同步！', textAlign: TextAlign.center)),
            );
          }
          return;
        }

        _updateSyncMessage('正在初始化同步...');
        // 1. Sync Trips
        await SyncHelper.syncTrips(
          option: option,
          auth: user,
          onProgress: (msg) {
            _updateSyncMessage('[行程] $msg');
          },
        );

        // 2. Sync Stories
        await SyncHelper.syncStories(
          option: option,
          auth: user,
          onProgress: (msg) {
            _updateSyncMessage('[故事] $msg');
          },
        );

        // 3. Refresh lists
        _updateSyncMessage('正在刷新本地视图数据...');
        final trips = await TravelDao.fetchAll('', 1);
        userData.setTrips(trips.allTripList);

        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          _syncMessageUpdater = null;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: Colors.blue, content: Text('数据同步成功！', textAlign: TextAlign.center)),
          );
        }
      } catch (e) {
        debugPrint('Sync failed: $e');
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          _syncMessageUpdater = null;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.red, content: Text('同步失败: $e', textAlign: TextAlign.center)),
          );
        }
      }
    });
  }

  void _jump(user){
    //行程初始化模版
    TravelModel trip = TravelModel(
      designer: user.name,
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
        onRefreshList: (){}
      )
    ));
  }

  @override
  Widget build(BuildContext context) {
    AuthModel user = Provider.of<UserData>(context).auth;
    List trips = Provider.of<UserData>(context).trips;
    return Scaffold(
      appBar: AppBar(
        title: const Text('DIY'),
        centerTitle:true,
        actions: [
          TextButton(
            child: const Text('新建行程', style: TextStyle(color: Colors.black)),
            onPressed: () =>_jump(user)    
          )
        ]
      ),
      body: (trips.isNotEmpty
      ?Stack(children: [
        ListView.builder(
          controller: _controller,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: trips.length,
          itemBuilder: (BuildContext context, int index){
            return GestureDetector(
              onTap: (){
                Provider.of<UserData>(context, listen: false).setCloneData(trips[index].copy());
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => MapDesign(
                    platform: widget.platform,
                    tripData: trips[index],
                    setTripData: widget.setTripData,
                    onRefreshList: (){}
                  )
                ));
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(5, 5, 5, 0),
                  child:Row(children: [
                    (trips[index].cover != '' || trips[index].detail[0].dayList[0].picURL != '')
                    ?CachedNetworkImage(
                      imageUrl: trips[index].cover != '' ? trips[index].cover : trips[index].detail[0].dayList[0].picURL,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) {
                        _handleImageError(trips[index]);
                        return Image.asset(
                          "assets/trip_fallback.png",
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        );
                      },
                    )
                    :Image.asset(
                      "assets/trip_fallback.png",
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                    Container(width: 5),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('${trips[index].tripName}',overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20.0,color: Colors.black)),
                        if (trips[index].designer != null && trips[index].designer!.isNotEmpty)
                          Text('设计人:  ${trips[index].designer}',style: const TextStyle(fontSize: 15.0,color: Colors.black)),
                      ],
                    )
                  ])
                )
            );
          },
        ),
        loading == true
        ?const Center(
          child: CircularProgressIndicator(),
        )
        :Container()
      ])
      :Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("本地暂无行程数据", style: TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                icon: const Icon(Icons.sync, color: Colors.white,),
                label: const Text("去同步数据", style: TextStyle(color: Colors.white),),
                onPressed: _showSyncDialog,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                icon: const Icon(Icons.add, color: Colors.white,),
                label: const Text("新建行程", style: TextStyle(color: Colors.white),),
                onPressed: () => _jump(user),
              ),
            ],
          ),
        ))
    );
  }
}