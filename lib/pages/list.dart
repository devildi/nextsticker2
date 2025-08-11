import 'package:flutter/material.dart';
import 'package:nextsticker2/model/travel_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math';
import 'package:nextsticker2/store/store.dart';
import 'package:provider/provider.dart';
import 'package:nextsticker2/dao/travel_dao.dart';
import 'package:nextsticker2/pages/arrange.dart';
import 'package:flutter_swiper_null_safety/flutter_swiper_null_safety.dart';
import 'package:nextsticker2/widgets/swiper_item.dart';
import 'package:flutter/services.dart';

class MyList extends StatefulWidget {
  final List trips;
  final TravelModel userData;
  final Function onRefresh;
  final Function getMore;
  final Function setTripData;
  final bool netWorkIsOn;
  final Function reFresh;
  final dynamic platform;
  const MyList({
    Key? key,
    required this.trips, 
    required this.userData, 
    required this.onRefresh,
    required this.getMore,
    required this.setTripData,
    required this.netWorkIsOn,
    required this.reFresh,
    required this.platform
    }): super(key: key);
  @override
  MyListState createState() => MyListState();
}

class MyListState extends State<MyList> with AutomaticKeepAliveClientMixin{
  @override
  bool get wantKeepAlive => true;
  static const platform = MethodChannel('gaode_api_channel');
  int page = 2;
  int pre = 0;
  bool loading = false;
  bool showBtn = false;

  final ScrollController _controller = ScrollController();
  final TextEditingController textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final SwiperController _swiperController = SwiperController();

  Future <void>_onRefresh() async{
    debugPrint('下拉刷新');
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

  void getMore(index) async{
    if(loading == true){
      //print(index);
      await widget.getMore("LIST", index);
      if (!context.mounted) return;
      if(Provider.of<UserData>(context, listen: false).netWorkStatus){
        setState(() {
          loading = false;
          pre = widget.trips.length;
          page = index + 1;
        });
      } else {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void _search(){
    Navigator.pushNamed(context, "search", arguments:{
      "userData": widget.userData,
      "fn": widget.setTripData
    });
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
          //showBtn = true;
          showBtn = false;
        });
      }
      if (_controller.position.pixels == _controller.position.maxScrollExtent) {
        if(widget.trips.length - pre == 20){
          debugPrint('开始加载更多数据');
          //print(page);
          _addMoreData(page);
        }else if(!Provider.of<UserData>(context, listen: false).netWorkStatus){
          _addMoreData(page);
        }
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    Provider.of<UserData>(context, listen: false).setSwiperIndex(0);
    _controller.dispose();
    _swiperController.dispose();
    textController.dispose();
    _focusNode.dispose();
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

  List<int> getIndex(str){
    List<String> parts = str.split('-');
    List<int> numbers = parts.map((s) {
      return int.tryParse(s) ?? 0; // 转换失败时返回0
    }).toList();
    return numbers;
  }
  

  void toLLM()async{
    List <DetailModel> tripList = [];
    List <String> tripListIndex = [];
    final double dialogWidth = MediaQuery.of(context).size.width - 40;
    if(textController.text == ''){
      //print('null');
      return;
    } else {
      Navigator.of(context).pop();
      _focusNode.unfocus();
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        builder: (context) {
          return Consumer<UserData>(
            builder: (context, userData, child) {
              //print(userData.fetchImgStatus);
              return Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // 重要：使Column只占用必要空间
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16), // 间距
                      Text(userData.fetchImgStatus, style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              );
            }
          );
        }
      );
      try{
        TravelModel trip = await TravelDao.fromLLM(textController.text);
        for (var i = 0; i < trip.detail.length; i++){
          for (var j = 0; j < trip.detail[i].dayList.length; j++){
            BingCover newUrl = await TravelDao.getBing(trip.detail[i].dayList[j].nameOfScence);
            // BingCover location = await TravelDao.getLocation(trip.detail[i].dayList[j].nameOfScence);
            String location = await callNativeMethod(trip.detail[i].dayList[j].nameOfScence);
            String longitude = location.split(',')[0];
            String latitude = location.split(',')[1];
            trip.detail[i].dayList[j].longitude = longitude;
            trip.detail[i].dayList[j].latitude = latitude;
            trip.detail[i].dayList[j].picURL = newUrl.bingUrl;

            if (!context.mounted) return;
            Provider.of<UserData>(context, listen: false).setFetchImgStatus('已获取【${trip.detail[i].dayList[j].nameOfScence}】的图片信息...');
            tripList.add(trip.detail[i].dayList[j]);
            tripListIndex.add('${i.toString()}-${j.toString()}');
          }
        }
        if (!context.mounted) return;
        Navigator.of(context).pop();
        textController.text = '';
        Provider.of<UserData>(context, listen: false).setFetchImgStatus('正在完善信息中，请耐心等待...');

        showDialog(
          context: context,
          builder: (context) => Dialog(
            insetPadding: const EdgeInsets.all(20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: dialogWidth,
                maxHeight: MediaQuery.of(context).size.height * 0.85, // 限制最大高度
              ),
              child: Swiper(
                controller: _swiperController,
                onIndexChanged: (index){
                  Provider.of<UserData>(context, listen: false).setSwiperIndex(index); // 更新当前页索引
                }, // 更新当前页索引
                itemCount: tripList.length,
                loop: false,
                index: Provider.of<UserData>(context, listen: false).swiperIndex, // 使用Provider获取当前页索引
                itemBuilder: (context, index) {
                return StatefulBuilder(
                  builder: (context, setState) {
                    return DetailCard(
                      trip: tripList[index],
                      tripIndex:tripListIndex[index],
                      dialogWidth: dialogWidth,
                      updateCategory: (newCategory) {
                        setState(() {
                          tripList[index].category = newCategory; // 直接修改原数据
                          trip.detail[getIndex(tripListIndex[index])[0]].dayList[getIndex(tripListIndex[index])[1]].category = newCategory;
                        });
                      },
                      jump: () { jump(trip); },
                      onDescriptionChanged: (newText) {
                        trip.detail[getIndex(tripListIndex[index])[0]].dayList[getIndex(tripListIndex[index])[1]].des = newText;
                      },
                    );
                    }
                  );
                },
                // Swiper配置
                layout: SwiperLayout.DEFAULT,
                //pagination: const SwiperPagination(),  // 添加分页指示器
                //control: const SwiperControl(),  // 添加导航按钮
              ),
            )
          ),
        );
      }catch(err){
        print(err);
        if (!context.mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('处理行程时发生错误'))
        );
        Provider.of<UserData>(context, listen: false).setFetchImgStatus('正在完善信息中，请耐心等待...');
      }
    }
  }

  Future<String> callNativeMethod(str) async {
    try {
      final result = await platform.invokeMethod('getLocation', str);
      print('原生方法返回: ${result['latLng']['longitude']},${result['latLng']['latitude']}');
      return '${result['latLng']['longitude']},${result['latLng']['latitude']}';
    } on PlatformException catch (e) {
      print("调用失败: '${e.message}'");
      return 'error';
    }
  }

  void jump(trip){
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => Arrange(
        tripData: trip,
        platform: widget.platform,
        width: MediaQuery.of(context).size.width,
        arrangeData: (){},
        delete: (){},
        from: 'list',
      )
    ));
  }

  void _ds(){
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            height: MediaQuery.of(context).size.height - 40,
            width: MediaQuery.of(context).size.width - 40,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: 150,  // Minimum height for the input field
                            maxHeight: MediaQuery.of(context).size.height * 0.6,  // Maximum height
                          ),
                          child: TextField(
                            controller: textController,
                            focusNode: _focusNode,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: '粘贴你的行程',
                              hintText: '你的行程可以来自小红书、微博及各种大模型...',
                              alignLabelWithHint: true,  // Proper label alignment for multi-line
                              contentPadding: EdgeInsets.all(12),
                            ),
                            keyboardType: TextInputType.multiline,
                            maxLines: null,  // null = unlimited lines (will expand)
                            minLines: 5,    // Initial minimum lines
                            textInputAction: TextInputAction.newline,  // Enter creates new line
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: toLLM,
                    child: const Text('提交'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((value) {
      //print('对话框已关闭');
      textController.text = '';
      Provider.of<UserData>(context, listen: false).setSwiperIndex(0);
    });
  }

  void deleteTrip(TravelModel trip) async{
    bool? confirm = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除行程'),
          content: const Text('你确定要删除这个行程吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      }
    );

    if (confirm == true) {
      await TravelDao.deleteTrip(trip.uid);
      widget.reFresh();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('行程已删除'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    AuthModel user = Provider.of<UserData>(context, listen: false).auth;
    super.build(context);
    //print(widget.trips[1].cover);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        leading:GestureDetector(onTap: _ds, child: Image.asset("assets/chatgpt.png")),
        title: GestureDetector(
          onTap: (){},
          child: const Text('NextSticker', style: TextStyle(color: Colors.white)),
        ),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.search), color: Colors.white, onPressed: _search)],
      ),
      body: (widget.trips.isEmpty != true
        ?Stack(
          children: [
            RefreshIndicator(
              onRefresh: _onRefresh,
              child: ListView.builder(
                controller: _controller,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: widget.trips.length,
                itemBuilder: (BuildContext context, int index){
                  return GestureDetector(
                    onTap: (){
                      Navigator.pushNamed(context, "detail", arguments:{
                        "passData": widget.trips[index],
                        "userData": widget.userData,
                        "fn": widget.setTripData,
                        "index": 1
                      });
                    },
                    onLongPress: user.name == widget.trips[index].designer? () => deleteTrip(widget.trips[index]) : (){},
                    child: Stack(
                      children: <Widget>[
                        Hero(
                          tag: widget.trips[index].uid,
                          child: CachedNetworkImage(
                            imageUrl: widget.trips[index]?.cover != '' ? widget.trips[index]?.cover : widget.trips[index].detail[0].dayList[0].picURL,
                            width: MediaQuery.of(context).size.width,
                            height: 180,
                            fit: BoxFit.cover,
                          )
                        ),
                        Center(
                          child: SizedBox(
                            height: 180,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text('${widget.trips[index].tripName}',style: const TextStyle(fontSize: 30.0,color: Colors.white)),
                                Text('by:  ${widget.trips[index].designer}',style: const TextStyle(fontSize: 20.0,color: Colors.white)),
                              ],
                            ),
                          )
                        )
                      ]
                    ),
                  );
                },
              )
            ),
            loading == true
            ?const Center(
              child: CircularProgressIndicator(),
            )
            :Container(),
          ],
        )
        :Center(
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
      floatingActionButton: showBtn
      ? FloatingActionButton(
        onPressed: (){
          _controller.animateTo(.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.ease
          );
        },
        heroTag: 3,
        child: const Icon(Icons.arrow_upward),
      ): null
    );
  }
}

Color randomColor(){
  List colors = [Colors.red[100], Colors.green[100], Colors.yellow[100], Colors.orange[100]];
  Random random = Random();
  return colors[random.nextInt(4)];
}