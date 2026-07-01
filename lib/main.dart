import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'dart:convert';
import 'package:nextsticker2/store/store.dart';
import 'package:nextsticker2/dao/travel_dao.dart';
import 'package:nextsticker2/dao/story_dao.dart';
import 'package:nextsticker2/model/article_model.dart';
import 'package:nextsticker2/model/travel_model.dart';
import 'package:nextsticker2/pages/detail.dart';
import 'package:nextsticker2/pages/gaodemap.dart';
import 'package:nextsticker2/pages/client.dart';
import 'package:nextsticker2/pages/search.dart';
import 'package:nextsticker2/pages/input.dart';
import 'package:nextsticker2/pages/chat.dart';
import 'package:nextsticker2/pages/list.dart';
import 'package:nextsticker2/pages/story.dart';
import 'package:nextsticker2/pages/my.dart';
import 'package:nextsticker2/pages/login.dart';
import 'package:nextsticker2/pages/register.dart';
import 'package:nextsticker2/pages/debt.dart';
import 'package:nextsticker2/pages/edit_micro.dart';
import 'package:nextsticker2/pages/edit_movie.dart';
import 'package:nextsticker2/widgets/bottom_navigation_bar.dart';
import 'package:nextsticker2/widgets/drawer.dart';
import 'package:nextsticker2/widgets/fab.dart';
import 'package:qiniu_flutter_sdk/qiniu_flutter_sdk.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:nextsticker2/widgets/queue.dart';
import 'package:nextsticker2/tools/tools.dart';
//websocket请求格式：'http://localhost:4000/socket.io/?EIO=4&transport=polling&t=OIUQBge'
//const wsURL = 'ws://10.214.72.50:4000';
//const wsURL = 'wss://nextsticker.cn';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    client.userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    return client;
  }
}

void main() async{
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  Provider.debugCheckInvalidValueType = null;
  SharedPreferences prefs = await SharedPreferences.getInstance();
  //await prefs.clear();
  String userDataString = prefs.getString('userData') ?? '';
  bool domestic = prefs.getBool('domestic') ?? true;
  String authString = prefs.getString('auth') ?? '';
  //print('domestic=$domestic');
  late TravelModel userDataConvert;
  if(userDataString != ''){
    dynamic obj = json.decode(userDataString);
    userDataConvert = TravelModel.fromJson(obj);
  } else {
    userDataConvert = TravelModel(detail: []);
  }
  late AuthModel authDataConvert;
  if(authString != ''){
    dynamic obj1 = json.decode(authString);
    authDataConvert = AuthModel.fromJson(obj1);
  } else {
    authDataConvert = AuthModel(
      like: [], 
      comment: [], 
      collect: [], 
      follow: [], 
      followed: []
    );
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
          value: UserData(
            userData: userDataConvert, 
            domestic: domestic,
            auth: authDataConvert,
            traficInfo: [],
            chatArray: [],
            chatUsers: [],
            trips: [],
            points: [],
            index: [],
            picsFromAlbum: [],
            cloneData: TravelModel(detail: [])
          )
        ),
      ],
      child: const MyApp()
    )
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NextSticker.cn',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      locale: const Locale('zh', 'CN'),
      initialRoute:"/",
      routes:{
        "detail": (context) => const Detail(),
        "registor": (context) => const NewClient(),
        "search": (context) => const Search(),
        "input": (context) => Input(sethasInput: (){}, getData: (){}),
        "login": (context) => const Login(),
        "debt": (context) => const Debt(),
        "editMicro": (context) => const EditMicro(),
        "editMovie": (context) => const EditMovie(),
        "chat": (context) => const Chat(),
        "register": (context) => const Register(),
      },
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const platform = MethodChannel('gaode_native_channel');
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<StoryState> storyKey = GlobalKey();
  final GlobalKey<MyListState> listKey = GlobalKey();
  final GlobalKey<GaodeMapState> mapKey = GlobalKey();

  final PageController _pageController = PageController();

  final TextEditingController _controller1 = TextEditingController();
  final TextEditingController _controller2 = TextEditingController();
  //final TextEditingController _controller3 = TextEditingController();

  List storyList = [];
  List tripList = [];
  int _selectedIndex = 0;
  //int _modalIndex = 0;

  DateTime _lastPopupOpenTime = DateTime.now();

  List storyListAuthor = [];
  List storyListLikes = [];
  List storyListCollects = [];

  bool isLoadingUserData = false;
  bool isKeepingtrail = false;

  bool hasInput = false;

  bool netWorkIsOn = true;

  late io.Socket socket;

  final storage = Storage();
  late PutController putController;
  
  double progress = 0.0;
  bool uploading = false;

  List<Future>tasks = [];

  late AsyncQueue queue;

  void sethasInput(bool flag){
    setState(() {
      hasInput = flag;
    });
  }

  void _openSnackBar(text, duration){
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, textAlign: TextAlign.center),
        duration: Duration(seconds: duration)
      )
    );
  }

  Future<void> _addMoreFromMyPage(string, uid, index) async{
    Provider.of<UserData>(context, listen: false).setNetWorkStatus(true);
    try{
      if(string == 'likes'){
        AllStoryModel storys = await StoryDao.likeOrCollect(index, uid, 'likes');
        setState((){
          storyListLikes = storys.storyList;
        });
      } else if(string == 'comments'){
        AllStoryModel storys = await StoryDao.likeOrCollect(index, uid, 'comments');
        setState((){
          storyListCollects = storys.storyList;
        });
      } else {
        AllStoryModel storys = await StoryDao.fetchByAuthor(index, uid);
        setState((){
          storyListAuthor = storys.storyList;
        });
      }
    }catch(err){
      debugPrint(err.toString());
    }
  }

  Future<void> _addMoreData(string, index) async{
    try{
      TravelModel userData = Provider.of<UserData>(context, listen: false).userData;
      if(string == 'STORY'){
        AllStoryModel storys = await StoryDao.fetch(index);
        setState(() {
          storyList = storys.storyList;
          Provider.of<UserData>(context, listen: false).setNetWorkStatus(true);
        });
      } else {
        AllTrip trips;
        if(userData.uid != ''){
          trips = await TravelDao.fetchAll(userData.uid, index);
        } else {
          trips = await TravelDao.fetchAll('', index);
        }  
        setState((){
          tripList = trips.allTripList;
          Provider.of<UserData>(context, listen: false).setTrips(trips.allTripList);
          Provider.of<UserData>(context, listen: false).setNetWorkStatus(true);
        });
      }
    }catch(err){
      _openSnackBar('网络错误，请重试！', 1);
      if (!context.mounted) return;
      Provider.of<UserData>(context, listen: false).setNetWorkStatus(false);
    }
  }

  Future<void> _onRefreshList() async{
    TravelModel userData = Provider.of<UserData>(context, listen: false).userData;
    AllTrip trips;
    if(userData.uid != ''){
      trips = await TravelDao.fetchAll(userData.uid, 1);
    } else {
      trips = await TravelDao.fetchAll('', 1);
    }  
    setState((){
      tripList = trips.allTripList;
    });
    if (!context.mounted) return;
    Provider.of<UserData>(context, listen: false).setTrips(trips.allTripList);
  }

  Future<void> _onRefreshStory() async{
    AllStoryModel storys = await StoryDao.fetch(1);
    setState((){
      storyList = storys.storyList;
    });
  }

  void loadingRouteState(flag){
    Provider.of<UserData>(context, listen: false).setLoadingRouteState(flag);
  }

  @override
  void initState(){
    super.initState();
    socket = io.io(CommonUtils.developmentMode ? CommonUtils.wsLan : 'wss://nextsticker.cn', <String, dynamic>{
        'transports': ['websocket'],
        'forceNew': true,
    }); 
    socket.on('connect', (_) {
      debugPrint('websocket connected..');
    });
    socket.on('data', (data){
      Provider.of<UserData>(context, listen: false).setchatArray(data);
    });
    socket.on('notification', (data){
      platform.invokeMethod('notification',data);
      _openSnackBar('NextSticker有新用户', 2);
    });
    socket.on('disconnect', (_){
      debugPrint('websocket disconnect');
    });
    socket.on('increase', (data){
      Provider.of<UserData>(context, listen: false).setNumInChatroom(data);
    });
    socket.on('decrease', (data){
      Provider.of<UserData>(context, listen: false).setNumInChatroom(data);
    });

    platform.setMethodCallHandler((call) async{
      switch (call.method) {
        case 'mapResumed':
          if (!context.mounted) return;
          TravelModel userData = Provider.of<UserData>(context, listen: false).userData;
          inJectToIOS(userData);
          int index = mapKey.currentState?.currentIndex ?? 0;
          platform.invokeMethod('changeCenter', index.toString());
          break;
        case 'openBottomSheet':
          dynamic content = await call.arguments;
          if (DateTime.now().difference(_lastPopupOpenTime).inMilliseconds < 400) {
            break;
          }
          if (!context.mounted) return;
          openBottomSheet(context, content);
          break;
        case 'openSnackBar':
          dynamic content = await call.arguments;
          String dis = (content[0] / 100 > 100 ? '${content[0] ~/1000}公里':'${content[0]}米');
          _openSnackBar('距离$dis，用时大约${content[1] ~/ 60}分钟', 5);
          if (!context.mounted) return;
          Provider.of<UserData>(context, listen: false).setTrafficInfo(content);
          break;
        case 'openSnackBarForBus':
          dynamic content = await call.arguments;
          if(content[0] == '0.0'){
            _openSnackBar('公交：用时${content[1] ~/ 60}分钟，走${content[2]}米', 5);
          } else {
            _openSnackBar('公交：花费${content[0]}元，用时${content[1] ~/ 60}分钟，走${content[2]}米', 5);
          }
          if (!context.mounted) return;
          Provider.of<UserData>(context, listen: false).setTrafficInfo(content);
          break;
        case 'aMapSearchRequestError':
          dynamic content = await call.arguments;
          if(content == ''){
            _openSnackBar('查无此路！', 3);
          } else {
            _openSnackBar(content, 3);
          }
          loadingRouteState(false);
          break;
        case 'domesticOrNot':
          bool content = await call.arguments;
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool('domestic', content);
          if (!context.mounted) return;
          Provider.of<UserData>(context, listen: false).setDomestic(content);
          break;
        case 'alert':
          if (!context.mounted) return;
          _openAlert(context);
          break;
        case 'permissionGranted':
          platform.invokeMethod('startLoaction');
          break;
        case 'clearInfor':
          Provider.of<UserData>(context, listen: false).setTrafficInfo([]);
          break;
        case 'isLoadingRoute':
          loadingRouteState(true);
          break;
        case 'stopLoadingRoute':
          loadingRouteState(false);
          break;
        case 'openModal':
          String content = await call.arguments;
          dynamic obj = json.decode(content);
          DetailModel item = DetailModel.fromJson(obj);
          _show(item);
          break;
        case 'addToDayList':
          String content = await call.arguments;
          dynamic obj = json.decode(content);
          DetailModel item = DetailModel.fromJson(obj);
          _addToDayList(item);
          break;
        case 'findPOIResults':
          String content = await call.arguments;
          if(content == 'error'){
            _openSnackBar('无搜索结果，请更换关键字', 3);
          }else {
            List obj = json.decode(content);
            Points points = Points.fromJson(obj);    
            // String result = points.toJson().toString();
            // debugPrint(result);
            if(points.pointList.isEmpty){
              _openSnackBar('无搜索结果，请更换关键字', 3);
            }
            if (!context.mounted) return;
            Provider.of<UserData>(context, listen: false).setPoints(points.pointList);
          }
          if (!context.mounted) return;
          Provider.of<UserData>(context, listen: false).setLoading(false);
          break;
        default:
          throw MissingPluginException();
      }
    });

    queue = AsyncQueue(concurrency: 3, maxRetries: 2)
    ..onTaskStart = (id){debugPrint("任务 $id 开始");} 
    ..onTaskDone = (id) {debugPrint("任务 $id 完成");} 
    ..onTaskError = (id, e) {debugPrint("任务 $id 出错: $e");} 
    ..onQueueEmpty = () {debugPrint("所有任务完成 ✅");};

    initData(
      Provider.of<UserData>(context, listen: false).userData,
      Provider.of<UserData>(context, listen: false).auth
    );
  }

  @override
  void dispose() {
    super.dispose();
    _pageController.dispose();
  }

  void initData(TravelModel userData1, AuthModel auth) async {
    //Provider.of<UserData>(context).setLoadingData(true);
    try{
      AllStoryModel storys = await StoryDao.fetch(1);
      AllStoryModel authorStorys = AllStoryModel(storyList: []);
      AllStoryModel likesStorys = AllStoryModel(storyList: []);
      AllStoryModel collectStorys = AllStoryModel(storyList: []);
      AllTrip trips;
      if(auth.name != ''){
        authorStorys = await StoryDao.fetchByAuthor(1, auth.uid);
        likesStorys = await StoryDao.likeOrCollect(1, auth.uid, 'likes');
        collectStorys = await StoryDao.likeOrCollect(1, auth.uid, 'comments');
      }
      if(userData1.uid != ''){
        trips = await TravelDao.fetchAll(userData1.uid, 1);
        setState((){
          storyList = storys.storyList;
          tripList = trips.allTripList;
          storyListAuthor = authorStorys.storyList;
          storyListLikes = likesStorys.storyList;
          storyListCollects = collectStorys.storyList;
        });
        //inJectToIOS(userData1);
      } else {
        trips = await TravelDao.fetchAll('', 1);
        setState((){
          storyList = storys.storyList;
          tripList = trips.allTripList;
          storyListAuthor = authorStorys.storyList;
          storyListLikes = likesStorys.storyList;
          storyListCollects = collectStorys.storyList;
        });
      }
      if (!context.mounted) return;
      Provider.of<UserData>(context, listen: false).setTrips(trips.allTripList);
      //Provider.of<UserData>(context, listen: false).setLoadingData(false);
    }catch(err){
      debugPrint(err.toString());
      _openSnackBar('网络错误，请重试！', 2);
      setState((){
        netWorkIsOn = false;
      });
    }
  }

  Future <void> openBottomSheet(context, dynamic input) async{
    TravelModel userData = Provider.of<UserData>(context, listen: false).userData;
    List allPoints = flatData(userData.detail);
    int index = -1;
    String name = '';
    List points = [];
    
    if (input is int) {
      index = input;
      if (index >= 0 && index < allPoints.length) {
        name = allPoints[index].nameOfScence;
        points = [allPoints[index]];
      }
    } else if (input is DetailModel) {
      index = allPoints.indexOf(input);
      name = input.nameOfScence;
      points = [input];
    } else if (input is String) {
      name = input;
      index = allPoints.indexWhere((element) => element.nameOfScence == name);
      if (index != -1) {
        points = [allPoints[index]];
      }
    }

    if (index == -1) return;

    _lastPopupOpenTime = DateTime.now();

    mapKey.currentState?.changePoint(index);
    platform.invokeMethod('setDestination', index);
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
            //mainAxisSize: MainAxisSize.min,
            //crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              points[0].picURL.isNotEmpty
              ?ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20.0),
                  topRight: Radius.circular(20.0),
                ),
                child: SafeNetworkImage(
                  imageUrl: points[0].picURL,
                  width: MediaQuery.of(context).size.width,
                  fit: BoxFit.cover,
                ),
              )
              :Container(),
              Padding(
                padding: EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 15.0 + MediaQuery.of(context).padding.bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            points[0].nameOfScence,
                            style: const TextStyle(fontSize: 25.0),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () async {
                                try {
                                  await platform.invokeMethod('navigetGoogle', 'bus');
                                } catch (e) {
                                  debugPrint('跳转谷歌地图失败: $e');
                                  if (context.mounted) {
                                    _openSnackBar('跳转谷歌地图失败: $e', 3);
                                  }
                                }
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              },
                              child: ClipOval(
                                child: Image.asset(
                                  "assets/google.png",
                                  width: 35,
                                  height: 35,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Container(
                              height: 25,
                              width: 1,
                              color: Colors.grey.withOpacity(0.5),
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            GestureDetector(
                              onTap: () async {
                                try {
                                  await platform.invokeMethod('navigetGaode', 'bus');
                                } catch (e) {
                                  debugPrint('跳转高德地图失败: $e');
                                  if (context.mounted) {
                                    _openSnackBar('跳转高德地图失败: $e', 3);
                                  }
                                }
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              },
                              child: ClipOval(
                                child: Image.asset(
                                  "assets/gaode.png",
                                  width: 35,
                                  height: 35,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    points[0].des.isNotEmpty
                    ?Text(points[0].des, style: const TextStyle(fontSize: 15.0))
                    :Container()
                  ],
                ),
              ),
            ],
          )
        );
      },
    );
  }
  void updateListItem(TravelModel newItem) {
    List newTripList = List.from(tripList); // 🔑 新列表
    int index = newTripList.indexWhere((item) => item.uid == newItem.uid);
    if (index != -1) {
      newTripList[index] = newItem;
      // setState(() {
      //  tripList = newTripList; 
      // });
    }
    Provider.of<UserData>(context, listen: false).setTrips(newTripList);
  }


  bool _pop(bool? check){
    Provider.of<UserData>(context, listen: false).setPicsFromAlbum([]);
    return true;
  }

  void _openAlert(BuildContext context){
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('需要定位权限'),
          content: const Text('请在「设置」—>「隐私」—>「定位服务」—>「NextSticker」中开启'),
          actions: <Widget>[
            TextButton(child: const Text('以后再说', style: TextStyle(color: Colors.grey),),onPressed: (){Navigator.of(context).pop();},),
            TextButton(child: const Text('去设置'),onPressed: (){Navigator.of(context).pop(
              platform.invokeMethod('openSysLocationPage')
            );},),
          ],
        );
      });
  }



  List flatData(array){
    List newArray = [];
    if(array != null){
      final List fixedList = Iterable<int>.generate(array.length).toList();
      fixedList.asMap().forEach((index, item) {
        array[index].dayList.forEach((i){
          newArray.add(i);
        });
      });
      return newArray;
    }
    return newArray;
  }

  List flatDataWithDayIndex(List<DayDetail> array) {
    List newArray = [];
    if (array != null) {
      for (int i = 0; i < array.length; i++) {
        for (var point in array[i].dayList) {
          var pointMap = point.toJson();
          pointMap['dayIndex'] = i;
          newArray.add(pointMap);
        }
      }
    }
    return newArray;
  }

  _addToDayList(DetailModel item){
    TravelModel cloneTrip = Provider.of<UserData>(context, listen: false).cloneData;
    item.category = 0;
    List indexAndCloneTripItem = CommonUtils.tripItemAndIndex(cloneTrip, item.nameOfScence);
    List index = indexAndCloneTripItem[1];
    if(index.isNotEmpty){
      debugPrint('存在重复的点${item.nameOfScence}：在第${index[0] + 1}天第${index[1] + 1}个');
      _openSnackBar('已存在该点：在第${index[0] + 1}天第${index[1] + 1}个', 2);
      Provider.of<UserData>(context, listen: false).setPoints([]);
      platform.invokeMethod('clear');
      return;
    }
    List location = Provider.of<UserData>(context, listen: false).index;
    if(location.isEmpty){
      location = [0, 0];
    }
    try{
      cloneTrip.detail[location[0]].dayList.add(item);
      if (!context.mounted) return;
      Provider.of<UserData>(context, listen: false).setCloneData(cloneTrip);
      Provider.of<UserData>(context, listen: false).setPoints([]);
      Provider.of<UserData>(context, listen: false).addProcessingName(item.nameOfScence);
      platform.invokeMethod('clear');
      //添加异步队列
      queue.addTask(
        cloneTrip.uid,
        () async {
        final results = await Future.wait([
          TravelDao.getBing(item.nameOfScence),
          TravelDao.getDes(item.nameOfScence),
        ]);
        if (!context.mounted) return;
        TravelModel newCloneTrip = Provider.of<UserData>(context, listen: false).cloneData;
        if(newCloneTrip.uid != ''){
          List index = CommonUtils.tripItemAndIndex(cloneTrip, item.nameOfScence)[1];
          if(index.isNotEmpty){
            cloneTrip.detail[index[0]].dayList[index[1]].picURL = results[0].bingUrl;
            cloneTrip.detail[index[0]].dayList[index[1]].des = results[1].bingUrl;
            if (!context.mounted) return;
            Provider.of<UserData>(context, listen: false).setCloneData(cloneTrip);
            debugPrint('已添加${item.nameOfScence}的图片和描述');
          }
        }else{
          TravelModel updatedTrip = await TravelDao.updatePoint(
            cloneTrip.uid, 
            item.nameOfScence, 
            results[1].bingUrl, 
            results[0].bingUrl
          );
          if(updatedTrip.uid != ''){
            updateListItem(updatedTrip);
            debugPrint('已在【后台】完善${item.nameOfScence}的图片和描述');
          }
        }
        if (context.mounted) {
          Provider.of<UserData>(context, listen: false).removeProcessingName(item.nameOfScence);
        }
      });
      _openSnackBar('已添加第${location[0] + 1}天第${cloneTrip.detail[location[0]].dayList.length}个点', 1);
    }catch(err){
      debugPrint(err.toString());
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.red, content: Text('添加点出错，请稍后再试！', textAlign: TextAlign.center)),
      );
    }
  }

  Future<void> _show(DetailModel item) async {
    TravelModel cloneTrip = Provider.of<UserData>(context, listen: false).cloneData;
    //List location = Provider.of<UserData>(context, listen: false).index;
    //print(location);
    // if(location.isEmpty){
    //   location = [0, 0];
    // }
    List indexAndCloneTripItem = CommonUtils.tripItemAndIndex(cloneTrip, item.nameOfScence);//检查是否有重复的点
    List index = indexAndCloneTripItem[1];
    DetailModel tripItem = indexAndCloneTripItem[0];
    if(index.isNotEmpty){
      debugPrint('存在重复的点${item.nameOfScence}：在第${index[0] + 1}天第${index[1] + 1}个');
    }
    if(tripItem.nameOfScence == ''){
      Provider.of<UserData>(context, listen: false).setLoading(true);
      _controller1.text = item.nameOfScence;
      _controller2.text = '';
      tasks.add(TravelDao.getBing(item.nameOfScence));
      tasks.add(TravelDao.getDes(item.nameOfScence));
      Future.wait(tasks).then((value){
          Provider.of<UserData>(context, listen: false).setPicBing(value[0].bingUrl);
          _controller2.text = value[1].bingUrl;
          Provider.of<UserData>(context, listen: false).setLoading(false);
          tasks.clear();
      });
    } else {
      _controller1.text = tripItem.nameOfScence;
      _controller2.text = tripItem.des;
    }
    
    void save(cat, location)async {
      if(tripItem.nameOfScence == ''){
        debugPrint('新建行程');
        item.category = cat;
        item.nameOfScence = _controller1.text;
        item.des = _controller2.text;
        item.picURL = Provider.of<UserData>(context, listen: false).picBing;
        if(location.isEmpty){
          location = [0, 0];
        }
        bool flag = await platform.invokeMethod('InjectOnePoint',item.toJson().toString());
        if(flag){
          cloneTrip.detail[location[0]].dayList.add(item);
          if (!context.mounted) return;
          Provider.of<UserData>(context, listen: false).setCloneData(cloneTrip);
          Provider.of<UserData>(context, listen: false).setPoints([]);
        }else {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: Colors.red, content: Text('添加点出错，请稍后再试！', textAlign: TextAlign.center)),
          );
        }
      } else {
        debugPrint('更改行程');
        cloneTrip.detail[index[0]].dayList[index[1]].nameOfScence = _controller1.text;
        cloneTrip.detail[index[0]].dayList[index[1]].des = _controller2.text;
        cloneTrip.detail[index[0]].dayList[index[1]].category = cat;
        String url = Provider.of<UserData>(context, listen: false).picBing;
        if(url != ''){
          cloneTrip.detail[index[0]].dayList[index[1]].picURL = url;
        }
        //cloneTrip.detail[index[0]].dayList[index[1]].picURL = _controller3.text;
        //print(cloneTrip.tripName);
        Provider.of<UserData>(context, listen: false).setCloneData(cloneTrip);
        bool flag = await platform.invokeMethod('InjectOnePoint',cloneTrip.detail[index[0]].dayList[index[1]].toJson().toString());
        if(flag){

        }
      }
      if (!context.mounted) return;
      Provider.of<UserData>(context, listen: false).setPicBing('');
      Provider.of<UserData>(context, listen: false).setDes('');
      Navigator.of(context).pop();
    }

    Widget anitext(){
      return AnimatedTextKit(
        animatedTexts: [
          TyperAnimatedText('.'),
          TyperAnimatedText('..'),
          TyperAnimatedText('...'),
          TyperAnimatedText('....'),
          TyperAnimatedText('.....'),
        ],
        totalRepeatCount: 100, // 重复次数（设为无限循环）
        displayFullTextOnTap: true,
        stopPauseOnTap: true,
      );
    }

    void fetchIMG(){
      Provider.of<UserData>(context, listen: false).setLoading(true);
      try{
        TravelDao.getBing(tripItem.nameOfScence).then((value){
          Provider.of<UserData>(context, listen: false).setPicBing(value.bingUrl);
          Provider.of<UserData>(context, listen: false).setLoading(false);
        });
      }catch(err){
        debugPrint(err.toString());
        Provider.of<UserData>(context, listen: false).setLoading(false);
      }
    }
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Consumer<UserData>(
          builder: (context, userData, child) {
            return PopScope(
              onPopInvoked: _pop,
              child: Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        tripItem.picURL !='' || userData.picBing != '' 
                        ?GestureDetector(
                          onTap: fetchIMG,
                          child: SafeNetworkImage(
                            imageUrl: userData.picBing != '' ? userData.picBing : tripItem.picURL,
                            fit: BoxFit.cover,
                            height: 150,
                          ),
                        )
                        :Container(),
                        const SizedBox(height: 20),
                        index.isNotEmpty
                        ?Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('第${index[0] + 1}天第${index[1] + 1}个景点', style: const TextStyle(fontSize: 16)),
                          ],
                        )
                        :Container(),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _controller1,
                          decoration: const InputDecoration(
                            labelText: '地点',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _controller2,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: '描述',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        userData.loading
                        ?Align(
                          alignment: Alignment.centerLeft, // 仅这个Text左对齐
                          child: Row(
                            children: [ const Text('图片链接和景点信息获取中'), anitext()],
                          ),
                        )
                        :Container(),
                        userData.loading
                        ?const SizedBox(height: 12)
                        :Container(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                userData.setCategory(0);
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: 0==userData.category ? Colors.blue : Colors.transparent,  // 背景颜色
                                foregroundColor: 0==userData.category ?Colors.white : Colors.blue, // 文字颜色
                                side: const BorderSide(color: Colors.blue), // 边框颜色
                              ),
                              child: const Text('景点'),
                            ),
                            OutlinedButton(
                              onPressed: () {
                                userData.setCategory(2);
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: 2==userData.category ? Colors.blue : Colors.transparent,  // 背景颜色
                                foregroundColor: 2==userData.category ?Colors.white : Colors.blue, // 文字颜色
                                side: const BorderSide(color: Colors.blue), // 边框颜色
                              ),
                              child: const Text('吃喝'),
                            ),
                            OutlinedButton(
                              onPressed: () {
                                userData.setCategory(1);
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: 1==userData.category ? Colors.blue : Colors.transparent,  // 背景颜色
                                foregroundColor: 1==userData.category ?Colors.white : Colors.blue, // 文字颜色
                                side: const BorderSide(color: Colors.blue), // 边框颜色
                              ),
                              child: const Text('住宿'),
                            )
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () { 
                                Navigator.pop(context);
                                Provider.of<UserData>(context, listen: false).setPicBing('');
                                Provider.of<UserData>(context, listen: false).setDes('');
                                Provider.of<UserData>(context, listen: false).setLoading(false);
                              },
                              child: Text('取消', style: TextStyle(color: Colors.blue[400])),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed:
                                userData.loading
                                ?() => {}
                                :() => save(userData.category, userData.index),
                              child: tripItem.nameOfScence == '' 
                                ? Text('添加至当日行程', style: TextStyle(
                                    color: userData.loading ? Colors.grey: Colors.blue[400]
                                  ),) 
                                : Text('保存修改', style: TextStyle(
                                    color: userData.loading ? Colors.grey: Colors.blue[400]
                                  ),),
                            ),
                          ],
                        ),
                      ],
                    )
                  ),
                ),
              )
            );
          }
        )
        ;
      },
    );
  }

  void openInforBar(){
    List infor = Provider.of<UserData>(context, listen: false).traficInfo;
    if(infor.length == 2){
      String dis = (infor[0] / 100 > 100 ? '${infor[0] ~/1000}公里':'${infor[0]}米');
      _openSnackBar('距离$dis，用时大约${infor[1] ~/ 60}分钟', 5);
    } else {
      if(infor[0] == '0.0'){
        _openSnackBar('用时${infor[1] ~/ 60}分钟，走${infor[2]}米', 5);
      } else {
        _openSnackBar('花费${infor[0]}元，用时${infor[1] ~/ 60}分钟，走${infor[2]}米', 5);
      }
    }
  }

  void _reFresh(){
    setState((){
      netWorkIsOn = true;
      initData(Provider.of<UserData>(context, listen: false).userData, Provider.of<UserData>(context, listen: false).auth);
    });
  }

  void tapLike(uid, articleId, type, index, flag) async{
    if(uid != ''){
      try{
        ArticleModel res = await StoryDao.clickLike({
          'type': type,
          'uid': uid,
          'articleId': articleId,
        });
        if(flag){
          int index1 = storyList.indexWhere((obj) => obj.articleId == articleId);
          if (index1 != -1) {
            storyList.insert(index1 + 1, res);
            storyList.removeAt(index1);
          }
        } else {
          storyList.insert(index + 1, res);
          storyList.removeAt(index);
        }
        setState(() {
          storyList = storyList;
        });
        initUserData(true);
      }catch(err){
        debugPrint(err.toString());
      }
    } else {
      debugPrint('请登录：');
      Navigator.pushNamed(context, "login", arguments: {
        "fn": _openSnackBar,
        "initUserData": initUserData
      });
    }
  }

  void comment(str, uid, articleId, index, flag) async{
    try{
      ArticleModel res = await StoryDao.poComment({
        'content': str,
        'uid': uid,
        'articleId': articleId,
      });
      if(flag != null){
        storyList.insert(index + 1, res);
        storyList.removeAt(index);
      } else {
        int index1 = storyList.indexWhere((obj) => obj.articleId == articleId);
        if (index1 != -1) {
          storyList.insert(index1 + 1, res);
          storyList.removeAt(index1);
        }
      }
      setState(() {
        storyList = storyList;
      });
      initUserData(true);
    }catch(err){
      debugPrint(err.toString());
    }
  }

  void initUserData(flag) async{
    if(flag){
      Provider.of<UserData>(context, listen: false).setLoading(true);
      AuthModel auth = Provider.of<UserData>(context, listen: false).auth;
      try{
        AllStoryModel storys = await StoryDao.fetch(1);
        AllStoryModel authorStorys = await StoryDao.fetchByAuthor(1, auth.uid);
        AllStoryModel likesStorys = await StoryDao.likeOrCollect(1, auth.uid, 'likes');
        AllStoryModel collectStorys = await StoryDao.likeOrCollect(1, auth.uid, 'comments');
        setState((){
          storyList = storys.storyList;
          storyListAuthor = authorStorys.storyList;
          storyListLikes = likesStorys.storyList;
          storyListCollects = collectStorys.storyList;
        });
        if (!context.mounted) return;
        Provider.of<UserData>(context, listen: false).setLoading(false);
      }catch(err){
        debugPrint(err.toString());
        Provider.of<UserData>(context, listen: false).setLoading(false);
      }
    } else {
      setState((){
        storyListAuthor = [];
        storyListLikes = [];
        storyListCollects = [];
      });
    }
  }

  void inJectToIOS(userData){
    String string = json.encode(flatDataWithDayIndex(userData.detail));
    platform.invokeMethod('InjectData', string);
  }

  List hotelData(array){
    List newArray = [];
    if(array != null){
      final List fixedList = Iterable<int>.generate(array.length).toList();
      fixedList.asMap().forEach((i, item) {
        if(array[i].category == 1){
          newArray.add(array[i]);
        }
      });
      return newArray;
    }
    return newArray;
  }

  List foodData(array){
    List newArray = [];
    if(array != null){
      final List fixedList = Iterable<int>.generate(array.length).toList();
      fixedList.asMap().forEach((i, item) {
        if(array[i].category == 2){
          newArray.add(array[i]);
        }
      });
      return newArray;
    }
    return newArray;
  }

  void getDataWithState(str){
    setState(() {
      isLoadingUserData = true;
      getData(str);
    });
  }

  void getData(str) async {
    try{
      TravelModel response = await TravelDao.fetch(str);
      //print(flatData(response.detail).length);
      //print(response.detail[0].dayList[0].nameOfScence);
      if(response.uid != ''){
        AllTrip trips = await TravelDao.fetchAll(response.uid, 1);
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('userData', json.encode(response));
        if (!context.mounted) return;
        UserData userData = Provider.of<UserData>(context, listen: false);
        userData.setUserData(response);
        setState(() {
          tripList = trips.allTripList;
          isLoadingUserData = false;
        });
        inJectToIOS(response);
        _openSnackBar('数据已导入！', 1);
        //print(jsonEncode(flatPOIs[0]));
      } else {
        setState(() {
          isLoadingUserData = false;
        });
        _openSnackBar('无对应编号！', 1);
      }
    } catch(err){
      _openSnackBar(err, 1);
    }
  }

  void _openDrawer(){
     _scaffoldKey.currentState?.openEndDrawer();
  }

  void _handleNavigationTap(int index) {
    if (index == _selectedIndex) {
      if (index == 2) {
        storyKey.currentState?.toTop();
      } else if (index == 1 && tripList.isNotEmpty) {
        listKey.currentState?.toTop();
      }
    }
    if (index == 0) {
      platform.invokeMethod('startLoaction');
    }
  }

  void _onItemTapped(int index){
    _handleNavigationTap(index);
    setState(() {
      _selectedIndex = index;
      _pageController.jumpToPage(index);
    });
  }

  Future <void>clearUserData() async{
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('userData');
    //print(prefs.getString('userData'));
    //await prefs.clear();
    if (!context.mounted) return;
    UserData userData = Provider.of<UserData>(context, listen: false);
    userData.setUserData(TravelModel(detail: []));
    userData.setWhichForDrawer(-1);
    setState((){
      isKeepingtrail = false;
    });
    Provider.of<UserData>(context, listen: false).setTrafficInfo([]);
    platform.invokeMethod('clear');
  }

  Future <void>logout() async{
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth');
    if (!context.mounted) return;
    UserData userData = Provider.of<UserData>(context, listen: false);
    userData.setAuth(
        AuthModel(
        like: [], 
        comment: [], 
        collect: [], 
        follow: [], 
        followed: []
      )
    );
    initUserData(false);
  }

  void setTripData(obj, index) async{
    Provider.of<UserData>(context, listen: false).setTrafficInfo([]);
    //platform.invokeMethod('clear');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('userData', json.encode(obj));
    if (!context.mounted) return;
    UserData userData = Provider.of<UserData>(context, listen: false);
    userData.setUserData(obj);
    if(index != 5){
      _openSnackBar('数据已导入!', 2);
    }
    inJectToIOS(obj);
    if(index != 5){
      Navigator.of(context).pop();
    }
    
    if(index == 2){
      Navigator.of(context).pop();
    }
    if(index != 5){
      _onItemTapped(0);
    }
  }

  void trail(){
    setState(() {
      isKeepingtrail = true;
      _openSnackBar('开始记录足迹！', 1 );
    });
  }

  void stopTrail(){
    setState(() {
      isKeepingtrail = false;
      _openSnackBar('已停止记录足迹！', 1);
    });
  }

  Future<void> _showMyDialog(context, index) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: index == 1 ? const Text('删除行程数据？') : const Text('开始记录足迹？'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                index == 1 ? const Text('输入行程编号可重新获取') : const Text('长按定位按钮可关闭'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('确定'),
              onPressed: () {
                if(index == 1){
                  clearUserData();
                } else{
                  debugPrint('开启鹰眼');
                  trail();
                }
                Navigator.of(context).pop();
              },
            )
          ],
        );
      },
    );
  }

  Widget which(dynamic userData, Widget A , Widget B){
    return userData?.domestic == 1 ? A : B;
  }

  Widget whichNoUserData(bool inChina, Widget A , Widget B){
    return inChina == true ? A : B;
  }

  @override
  Widget build(BuildContext context) {
    TravelModel userData = Provider.of<UserData>(context).userData;
    bool inChina = Provider.of<UserData>(context).domestic;
    int whichForDrawer = Provider.of<UserData>(context).whichForDrawer;
    AuthModel auth = Provider.of<UserData>(context).auth;

    void check(param) async{
      userData.detail.asMap().forEach((index, value){
        value.dayList.asMap().forEach((index1, i){
          if(i.nameOfScence == param){
            i.done = !i.done;
          }
        }); 
      });
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('userData', json.encode(userData));
      if (!context.mounted) return;
      Provider.of<UserData>(context, listen: false).setUserData(userData);
      platform.invokeMethod('check', param);
    }

    void setWhich(param){
      Provider.of<UserData>(context, listen: false).setWhichForDrawer(param);
    }

    return
      hasInput == false
      ?Scaffold(
        key: _scaffoldKey,
        body: PageView(
          onPageChanged: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: <Widget>[
            GaodeMap(
              key: mapKey,
              domestic: inChina,
              openSnackBar: _openSnackBar, 
              points: json.encode(flatDataWithDayIndex(userData.detail)),
              hotelPoints: json.encode(hotelData(flatData(userData.detail)).map((i) => i.toJson()).toList()),
              foodPoints: json.encode(foodData(flatData(userData.detail)).map((i) => i.toJson()).toList()),
              platform: platform,
              userData: userData,
              showMyDialog: _showMyDialog,
              openDrawer: _openDrawer,
              isLoading: isLoadingUserData,
              isKeepingtrail: isKeepingtrail,
              stopTrail: stopTrail,
              sethasInput: sethasInput,
              getDataWithState:getDataWithState,
              openBottomSheet: openBottomSheet,
              openInforBar:openInforBar,
              setTripData: setTripData,
            ),
            MyList(
              key: listKey,
              trips: tripList, 
              onRefresh: _onRefreshList, 
              getMore: _addMoreData,
              setTripData: setTripData,
              userData: userData,
              netWorkIsOn: netWorkIsOn,
              reFresh: _reFresh,
              platform: platform,
              updateListItem: updateListItem,
              initUserData: initUserData,
            ),
            Story(
              key: storyKey,
              isActive: _selectedIndex == 2,
              storys: storyList, 
              onRefresh: _onRefreshStory, 
              getMore: _addMoreData,
              netWorkIsOn: netWorkIsOn,
              reFresh: _reFresh,
              openSnackBar: _openSnackBar,
              auth: auth,
              platform: platform,
              socket: socket,
              tapLike: tapLike,
              comment: comment,
              initUserData: initUserData
            ),
            Myself(
              openSnackBar: _openSnackBar,
              auth: auth,
              logout: logout,
              storyListAuthor: storyListAuthor,
              storyListLikes: storyListLikes,
              storyListCollects: storyListCollects,
              platform: platform,
              tapLike: tapLike,
              comment: comment,
              getMore: _addMoreFromMyPage,
              initUserData: initUserData,
              netWorkIsOn: netWorkIsOn,
              setTripData: setTripData,
              getMoreTripData: _addMoreData,
              onRefresh: _onRefreshList, 
            )
          ]
        ),
        endDrawer: userData.uid != '' 
        ? MyDrawer(
          destinations: userData.detail,
          check: check,
          openBottomSheet: openBottomSheet,
          whichForDrawer: whichForDrawer,
          setWhich: setWhich
        )
        : null,
        bottomNavigationBar: MyBottomNavigationBar(
          selectedIndex: _selectedIndex,
          onItemTapped: _onItemTapped
        ),
        endDrawerEnableOpenDragGesture: (userData.uid != ''  && _selectedIndex == 0 ? true : false),
        floatingActionButton: _selectedIndex == 7 
        ? MyFAB(
          platform: platform,
          isKeepingtrail: isKeepingtrail,
          stopTrail: stopTrail
        ) 
        : null,
      )
      :Visibility(
        visible: hasInput,
        child: Input(
          sethasInput: sethasInput,
          getData: getDataWithState
        )
      );
  }
}

class SafeNetworkImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;

  const SafeNetworkImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  @override
  _SafeNetworkImageState createState() => _SafeNetworkImageState();
}

class _SafeNetworkImageState extends State<SafeNetworkImage> {
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    if (_hasError || widget.imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }
    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      httpHeaders: const {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      fadeInDuration: const Duration(milliseconds: 200),
      errorWidget: (context, url, error) {
        if (!_hasError) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _hasError = true;
              });
            }
          });
        }
        return const SizedBox.shrink();
      },
    );
  }
}