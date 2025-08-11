import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nextsticker2/model/travel_model.dart';
import 'dart:convert' as convert;
import 'package:nextsticker2/store/store.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_swiper_null_safety/flutter_swiper_null_safety.dart';

class GaodeMap extends StatefulWidget {
  final String points;
  final String hotelPoints;
  final String foodPoints;
  final bool isLoading;
  final TravelModel userData;
  final Function openSnackBar;
  final Function showMyDialog;
  final Function openDrawer;
  final dynamic platform;
  final bool isKeepingtrail;
  final Function stopTrail;
  final Function sethasInput;
  final bool domestic;
  final Function getDataWithState;
  final Function openBottomSheet;
  final Function openInforBar;
  final Function setTripData;
  const GaodeMap({
    Key? key,
    required this.points,
    required this.hotelPoints,
    required this.foodPoints,
    required this.isLoading,
    required this.userData,
    required this.showMyDialog,
    required this.openSnackBar,
    required this.platform,
    required this.openDrawer,
    required this.isKeepingtrail,
    required this.stopTrail,
    required this.sethasInput,
    required this.domestic,
    required this.getDataWithState,
    required this.openBottomSheet,
    required this.openInforBar,
    required this.setTripData,
  }): super(key: key);

  @override
  GaodeMapState createState() => GaodeMapState();
}

class GaodeMapState extends State<GaodeMap> with AutomaticKeepAliveClientMixin 
{
  @override
  bool get wantKeepAlive => true;

  GlobalKey<GaodeMapState> gaodeKey = GlobalKey();
  late SwiperController _swiperController;
  int currentIndex = 0;

  Widget genLeading(){
    if(widget.userData.uid == ''){
      return Container();
    } else {
      return GestureDetector(child: const Icon(Icons.expand_more, color: Colors.white),onTap: (){
        openBottomSheet1(context);     
      });
    }
  }

  Future <void> openBottomSheet1(context)async{
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
      ),
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: ListBody(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(0, 0, 0, MediaQuery.of(context).padding.bottom),
                child: ListTile(
                  leading: const Icon(Icons.remove_circle_outline), 
                  title: const Text('删除此行程'),
                  onTap: (){
                    Navigator.pop(context);
                    widget.showMyDialog(context, 1); 
                  },
                ),
              )
            ],
          )
        );
      },
    );
  }
  
  void naviToInput(){
    if(defaultTargetPlatform == TargetPlatform.android){
      Navigator.pushNamed(context, "input", arguments:{
         "fn": widget.getDataWithState
      });
    } else {
      widget.sethasInput(true);
    }
  }

  String getWhich(userData, domestic){
    if(userData.tripName == ''){
      return domestic == true ? 'gaode_native_IOS' : 'google_native_IOS';
      //return domestic == true ? 'google_native_IOS' : 'google_native_IOS';
    } else if(userData.domestic == 1){//1国内 0国外
      return 'gaode_native_IOS';
    } else {
      return 'google_native_IOS';
    }
  }

  Widget platformView1(points) {
    if (defaultTargetPlatform == TargetPlatform.android && getWhich(widget.userData, widget.domestic) == 'gaode_native_IOS') {
      return AndroidView(
        key: gaodeKey,
        viewType: 'gaode_native_IOS',
        creationParams: {'pointsString': points},
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated:(viewId){
          //debugPrint('gaode_native_viewId:$viewId');
        },
      );
    }else {
      return AndroidView(
        viewType: 'google_native_IOS',
        creationParams: {'pointsString': points},
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated:(viewId){
          debugPrint('google_native_viewId:$viewId');
        },
      );
    }
  }

  Widget platformView(points) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        viewType: getWhich(widget.userData, widget.domestic),
        creationParams: {'pointsString': points},
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated:(viewId){
          debugPrint('viewId:$viewId');
        },
      );
    }else {
      return UiKitView(
        viewType: getWhich(widget.userData, widget.domestic),
        onPlatformViewCreated:(viewId){
          //print('viewId:$viewId');
        },
        creationParams: points,
        creationParamsCodec: const StandardMessageCodec()
      );
    }
  }

  Future<void> openFoodAndHotelDialog() async{
    List <Widget>dataArray = [];
    List <Widget>foodItems = [];
    List hotelsArray = convert.jsonDecode(widget.hotelPoints);
    List foodsArray = convert.jsonDecode(widget.foodPoints);
    final List fixedListHotel = Iterable<int>.generate(hotelsArray.length).toList();
    final List fixedListFood = Iterable<int>.generate(foodsArray.length).toList();
    fixedListHotel.asMap().forEach((i, item){
      dataArray.add(hotel(hotelsArray[i]["nameOfScence"], context, widget.openBottomSheet));
    });
    fixedListFood.asMap().forEach((i, item){
      foodItems.add(foodItem(foodsArray[i]["nameOfScence"], context, widget.openBottomSheet));
    });
    dataArray.add(foods(foodItems));
    await showDialog(
      context: context, 
      builder: (context){
        return SimpleDialog(
          title: const Text('住宿安排 | 小吃推荐'),
          children: dataArray,
        );
      }
    );
  }

  Widget hotel(str, context, fn){
    return 
      SimpleDialogOption(
        child: Text(str, style: const TextStyle(fontSize: 20),),
        onPressed: (){Navigator.pop(context);fn(context, str);},
      );
  }

  Widget foods(foodItems){
    return
      Container(
        padding: const EdgeInsets.fromLTRB(21, 0, 0, 0),
        child: Wrap(
          children: foodItems
        ),
      );
  }

  void navigat(){
    widget.platform.invokeMethod('naviget','naviget');
  }

  void callTexi(){
    widget.platform.invokeMethod('callTexi', 'callTexi');
  }

  Widget foodItem(str, context, fn){
    return
      GestureDetector(
        child: Container(
          margin: const EdgeInsets.fromLTRB(0, 0, 3, 0),
          child: Chip(
          label: Text(str, style: const TextStyle(color: Colors.white),),
          backgroundColor: Colors.blue)
        ),
        onTap: (){Navigator.pop(context);fn(context, str);},
      );
  }
  
  @override
  void initState(){
    super.initState();
    debugPrint('地图page初始化！');
    _swiperController = SwiperController();
  }

  @override
  void dispose(){
    _swiperController.dispose();
    super.dispose();
    debugPrint('地图page销毁！');
  }

  void open (){
    widget.openInforBar();
  }

  void _search(){
    Navigator.pushNamed(context, "search", arguments:{
      "userData": widget.userData,
      "fn": widget.setTripData
    });
  }

  void changePoint(int index){
    setState(() {
      currentIndex = index;
    });
    _swiperController.move(index);
    widget.platform.invokeMethod('changeCenter', index.toString());
  }

  void tapBar(int index){
    _swiperController.move(index);
    widget.platform.invokeMethod('changeCenter', index.toString());
  }

  void testXianyu()async{
    
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    //print('gaode:${Provider.of<UserData>(context, listen: false).traficInfo}');
    List state = Provider.of<UserData>(context, listen: false).traficInfo;
    List pointsArray = Points.fromJson(convert.jsonDecode(widget.points)).pointList;
    
    return Scaffold(
      appBar: 
      AppBar(
        backgroundColor: Colors.blue,
        leading: genLeading(),
        centerTitle:true,
        title: GestureDetector(
          onTap: testXianyu,
          child: const Text(
            'NextSticker',
            style: TextStyle(color: Colors.white),
          ),
        ),
        actions: <Widget>[
          widget.userData.uid == ''
          ?IconButton(icon: const Icon(Icons.search), color: Colors.white, onPressed: _search)
          // TextButton(
          //   onPressed: naviToInput,
          //   child: const Text('行程编号', style: TextStyle(color: Colors.black))
          // )
          :IconButton(onPressed: widget.openDrawer as VoidCallback, icon: const Icon(Icons.dehaze), color: Colors.white)
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child:SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: platformView1(widget.points)
            ),
          ),
          widget.isLoading == true
          ?const Center(
            child: CircularProgressIndicator(),
          )
          : Container(),
          widget.foodPoints == '[]' && widget.hotelPoints == '[]'
          ?Container()
          :Positioned(
            left: 5,
            top: 2,
            child: GestureDetector(
              onTap: openFoodAndHotelDialog,
              child: Chip(
                avatar: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: ClipOval(child: Image.asset("assets/hotel.png")),
                ),
                label: const Text('住宿安排和小吃推荐', style: TextStyle(color: Colors.white),),
                backgroundColor: Colors.blue,),
              ),  
          ),
          widget.userData.uid != '' && state.isEmpty == true
          ?Positioned(
            bottom: 15, // 设置底部距离为15像素
            left: 0,
            right: 0,
            child: SizedBox(
              height: 50, // 保持Swiper高度不变
              child: Swiper(
                controller: _swiperController,
                itemCount: pointsArray.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => tapBar(index),
                    child: Container(
                      width: 200,
                      height: 50, // GestureDetector高度为50
                      color: Colors.grey[200],
                      alignment: Alignment.center,
                      child:  Row(
                      mainAxisSize: MainAxisSize.min, // 让 Row 仅占用所需空间
                      children: [
                        const SizedBox(width: 10),
                        Text(
                          '${currentIndex + 1}：',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: NetworkImage(pointsArray[currentIndex].picURL), 
                        ),
                        const SizedBox(width: 10),
                        Text(
                          pointsArray[currentIndex].nameOfScence,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10), // 间距
                      ],
                    )
                    ),
                  );
                },
                onIndexChanged: (index) => changePoint(index),
                loop: false,
                scrollDirection: Axis.horizontal,
                control: const SwiperControl(),
                viewportFraction: 0.8,
                scale: 0.5,
              ),
            ),
          )
          :Container(),
          widget.userData.uid == ''
          ?Container()
          :Positioned(
            left: 5,
            bottom: 14,
            child: Row(children: [
              state.isEmpty != true
              ?GestureDetector(
                onTap: open,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(0, 0, 5, 0),
                  child: Chip(
                    avatar: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: ClipOval(child: Image.asset("assets/info.png")),
                    ),
                    backgroundColor: Colors.blue,
                    label: const Text('路线',style: TextStyle(color: Colors.white)),
                  ),
                ),
              )
              :Container(),
              state.isEmpty != true
              ?GestureDetector(
                onTap: navigat,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(0, 0, 5, 0),
                  child: Chip(
                    avatar: CircleAvatar(
                      child: ClipOval(child: Image.asset("assets/gaode.png")),
                      //backgroundColor: Colors.grey.shade800,
                    ),
                    backgroundColor: Colors.blue,
                    label: const Text('导航',style: TextStyle(color: Colors.white)),
                  ),
                ),
              )
              :Container(),
              state.isEmpty != true
              ?GestureDetector(
                onTap: callTexi,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(0, 0, 5, 0),
                  child: Chip(
                    avatar: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: ClipOval(child: Image.asset("assets/taxi.png")),
                    ),
                    backgroundColor: Colors.blue,
                    label: const Text('叫车',style: TextStyle(color: Colors.white)),
                  ),
                ),
              )
              :Container(),
            ],),
          ),
          Provider.of<UserData>(context, listen: false).loadingRouteState
          ?const Center(
            child: CircularProgressIndicator(),
          )
          : Container(),
        ],
      )
    );
  }
}