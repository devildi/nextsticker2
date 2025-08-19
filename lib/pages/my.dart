import 'package:flutter/material.dart';
import 'package:nextsticker2/model/travel_model.dart';
import 'package:nextsticker2/pages/mypo.dart';
//import 'package:nextsticker2/pages/tool.dart';
import 'package:nextsticker2/pages/diy.dart';
import 'package:provider/provider.dart';
import 'package:nextsticker2/store/store.dart';
import 'package:nextsticker2/pages/map_design.dart';

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
  }): super(key: key);
  @override
  MyselfState createState() => MyselfState();
}

class MyselfState extends State<Myself> with TickerProviderStateMixin {
  late TabController _tabController;
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

  // void _submit(){
  //   Navigator.pushNamed(context, "registor", arguments: widget.openSnackBar);

  // }
  
  // void _jumpToToolPage(){
  //   if(widget.auth.name == 'wudi'){
  //     Navigator.push(context, MaterialPageRoute(
  //       builder: (context) => Tool(
  //         platform: widget.platform
  //       )
  //     ));
  //   }
  // }

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
          Container(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 0),
            height: MediaQuery.of(context).size.height / 2 - 200,
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
                    ?GestureDetector(
                      onTap: _changeAvata,
                      child: Container(
                        padding: const EdgeInsets.only(left: 20),
                        child: Text(widget.auth.name, style: const TextStyle(color: Colors.white, fontSize: 25),),
                      ),
                    )
                    :GestureDetector(
                      onTap: _logon,
                      child: Container(
                        padding: const EdgeInsets.only(left: 20),
                        child: const Text('登录 | 注册',style: TextStyle(color: Colors.white, fontSize: 25),),
                      ),
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
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  offset: Offset(15.0, 15.0), //阴影xy轴偏移量
                  blurRadius: 15.0, //阴影模糊程度
                  spreadRadius: 1.0 //阴影扩散程度
                )
              ]
            ),
            height: 100,
            margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            transform: Matrix4.translationValues(0, -50, 0),
            child: Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                icon: const Icon(Icons.send, color: Colors.white,),
                label: const Text("我要定制",style: TextStyle(color: Colors.white),),
                //onPressed: _submit,
                onPressed:  widget.auth.name != '' ? () =>_jump(user) : _logon,
              ),
            )
          ),
          TabBar(
            controller: _tabController,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            //isScrollable: true,
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