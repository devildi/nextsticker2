import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'dart:convert';
//import 'dart:io';
//import 'package:flutter/foundation.dart';
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
//import 'package:image_picker/image_picker.dart';
//import "package:images_picker/images_picker.dart";
//import 'package:nextsticker2/dao/newclient_dao.dart';
//websocket请求格式：'http://localhost:4000/socket.io/?EIO=4&transport=polling&t=OIUQBge'
//const wsURL = 'ws://localhost:4000';
const wsURL = 'wss://nextsticker.cn';

void main() async{
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
    socket = io.io(wsURL, <String, dynamic>{
        'transports': ['websocket'],
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
        case 'openBottomSheet':
          dynamic content = await call.arguments;
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
          _openAlert(context);
          break;
        case 'getPoster':
          //dynamic content = await call.arguments;
          //print(content);
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

  Future <void> openBottomSheet(context, string) async{
    TravelModel userData = Provider.of<UserData>(context, listen: false).userData;
    List allPoints = flatData(userData.detail);
    int index = allPoints.indexWhere((element) => element.nameOfScence == string);
    mapKey.currentState?.changePoint(index);
    platform.invokeMethod('setDestination',string);
    List points = allPoints.where((element) => element.nameOfScence == string).toList();
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
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20.0),
                  topRight: Radius.circular(20.0),
                ),
                child: CachedNetworkImage(
                  imageUrl: points[0].picURL,
                  width: MediaQuery.of(context).size.width,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(3.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(points[0].nameOfScence, style: const TextStyle(fontSize: 25.0)),
                        // FlatButton(
                        //   onPressed: (){
                        //     userData.detail.forEach((value){
                        //       value.dayList.forEach((i){
                        //         if(i.nameOfScence == string){
                        //           print(i.done);
                        //           i.done = !i.done;
                        //         }
                        //       }); 
                        //     });
                        //     Provider.of<UserData>(context, listen: false).setUserData(userData);
                        //   },
                        //   child: Text(points[0].done ? '取消打卡' : '打卡', style: TextStyle(fontSize: 20.0)),
                        // )
                      ],
                    ),
                    Text(points[0].des, style: const TextStyle(fontSize: 15.0))
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(3, 3, 3, MediaQuery.of(context).padding.bottom),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    clickwhich(const Icon(Icons.directions_bus,size: 30.0),'bus', context),
                    clickwhich(const Icon(Icons.directions_walk,size: 30.0),'walk', context),
                    clickwhich(const Icon(Icons.directions_bike,size: 30.0),'bike', context),
                    clickwhich(const Icon(Icons.directions_car,size: 30.0),'car', context)
                  ],
                )
              )
            ],
          )
        );
      },
    );
  }

  Widget clickwhich(icon, string, ctx){
    num domestic = Provider.of<UserData>(context, listen: false).userData.domestic;
    
    return GestureDetector(
      child:icon,
      onTap: (){
        if(domestic == 1){
          platform.invokeMethod('genRoute', string);
        } else {
          platform.invokeMethod('toGoogleMapApp', string);
        }
        Navigator.pop(ctx);  
      }
    );
  }

  bool _pop(bool? check){
    Provider.of<UserData>(context, listen: false).setPicsFromAlbum([]);
    return true;
  }

  void _openAlert(context){
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

  Future<void> _show(DetailModel item) async {
    TravelModel cloneTrip = Provider.of<UserData>(context, listen: false).cloneData;
    //List location = Provider.of<UserData>(context, listen: false).index;
    //print(location);
    // if(location.isEmpty){
    //   location = [0, 0];
    // }
    List indexAndCloneTripItem = indexAndTripItem(cloneTrip, item.nameOfScence);
    List index = indexAndCloneTripItem[1];
    DetailModel tripItem = indexAndCloneTripItem[0];
    
    if(tripItem.nameOfScence == ''){
      Provider.of<UserData>(context, listen: false).setLoading(true);
      _controller1.text = item.nameOfScence;
      _controller2.text = '';
      //_controller3.text = '';
      // TravelDao.getBing(item.nameOfScence).then((value){
      //     debugPrint(value.bingUrl);
      //     Provider.of<UserData>(context, listen: false).setPicBing(value.bingUrl);
      //   } 
      // );
      // TravelDao.getDes(item.nameOfScence).then((value){
      //     _controller2.text = value.bingUrl;
      //   } 
      // );
      tasks.add(TravelDao.getBing(item.nameOfScence));
      tasks.add(TravelDao.getDes(item.nameOfScence));
      Future.wait(tasks).then((value){
          Provider.of<UserData>(context, listen: false).setPicBing(value[0].bingUrl);
          //Provider.of<UserData>(context, listen: false).setDes(value[1].bingUrl);
          _controller2.text = value[1].bingUrl;
          Provider.of<UserData>(context, listen: false).setLoading(false);
          tasks.clear();
      });
    } else {
      _controller1.text = tripItem.nameOfScence;
      _controller2.text = tripItem.des;
      //_controller3.text = tripItem.picURL;
    }

    // Future startUploadToQiniu(token, path) async{
    //   putController = PutController();
    //   putController.addSendProgressListener((double percent) {
    //     debugPrint('已上传进度变化：已发送：$percent');
    //   });
    //   debugPrint('添加任务进度订阅');
    //   putController.addProgressListener((double percent) {
    //     setState(() {
    //       progress = percent;
    //     });
    //     debugPrint('任务进度变化：已发送：$percent');
    //   });
    //   debugPrint('添加状态订阅');
    //   putController.addStatusListener((StorageStatus status) {
    //     debugPrint('状态变化: 当前任务状态：$status');
    //   });
    //   debugPrint('开始上传文件');
    //   final putOptions = PutOptions(
    //     controller: putController
    //   );
    //   Future<PutResponse> upload;
    //   upload = storage.putFile(
    //     File(path),
    //     token,
    //     options: putOptions,
    //   );
    //   try{
    //     PutResponse response = await upload;
    //     debugPrint('上传已完成: 原始响应数据: ${ReturnBody.fromJson(response.rawData)}');
    //     debugPrint('------------------------');
    //     ReturnBody body = ReturnBody.fromJson(response.rawData);
    //     return body;
    //   } catch(error){
    //     if (error is StorageError) {
    //       switch (error.type) {
    //         case StorageErrorType.CONNECT_TIMEOUT:
    //           debugPrint('发生错误: 连接超时');
    //           break;
    //         case StorageErrorType.SEND_TIMEOUT:
    //           debugPrint('发生错误: 发送数据超时');
    //           break;
    //         case StorageErrorType.RECEIVE_TIMEOUT:
    //           debugPrint('发生错误: 响应数据超时');
    //           break;
    //         case StorageErrorType.RESPONSE:
    //           debugPrint('发生错误: ${error.message}');
    //           break;
    //         case StorageErrorType.CANCEL:
    //           debugPrint('发生错误: 请求取消');
    //           break;
    //         case StorageErrorType.UNKNOWN:
    //           debugPrint('发生错误: 未知错误');
    //           break;
    //         case StorageErrorType.NO_AVAILABLE_HOST:
    //           debugPrint('发生错误: 无可用 Host');
    //           break;
    //         case StorageErrorType.IN_PROGRESS:
    //           debugPrint('发生错误: 已在队列中');
    //           break;
    //       }
    //     } else {
    //       debugPrint('发生错误: ${error.toString()}');
    //     }
    //     debugPrint('------------------------');
    //   }
    // }

    // Future addPic() async {
    //   List res;
    //   if(defaultTargetPlatform == TargetPlatform.iOS){
    //     res = await (ImagesPicker.pick(
    //       count: 1,
    //       pickType: PickType.image
    //     )) as List<dynamic>;
    //   } else {
    //     final ImagePicker picker = ImagePicker();
    //     res = await picker.pickMultiImage();
    //   }
    //   if(res.isNotEmpty){
    //     if (!context.mounted) return;
    //     Provider.of<UserData>(context, listen: false).setPicsFromAlbum(res);
    //   }
    // }

    // void up()async{
    //   List medias = Provider.of<UserData>(context, listen: false).picsFromAlbum;
    //   try{
    //     String token = await Micro.getToken('');
    //     ReturnBody body = await startUploadToQiniu(token, medias[0].path);
    //     _controller3.text = 'http://nextsticker.top/${body.key}';
    //     setState(() {
    //       uploading = false;
    //     });
    //   } catch(err){
    //     debugPrint(err.toString());
    //     setState(() {
    //       uploading = false;
    //       ScaffoldMessenger.of(context).showSnackBar(
    //         const SnackBar(backgroundColor: Colors.red, content: Text('网络错误，请稍后再试！', textAlign: TextAlign.center)),
    //       );
    //     });
    //   }
    // }

    // void upload() async{
    //   setState(() {
    //     uploading = true;
    //     up();
    //   });
    // }
    
    void save(cat, location){
      if(tripItem.nameOfScence == ''){
        debugPrint('新建行程');
        item.category = cat;
        item.nameOfScence = _controller1.text;
        item.des = _controller2.text;
        item.picURL = Provider.of<UserData>(context, listen: false).picBing;
        if(location.isEmpty){
          location = [0, 0];
        }
        //print(location);
        cloneTrip.detail[location[0]].dayList.add(item);
        Provider.of<UserData>(context, listen: false).setCloneData(cloneTrip);
        platform.invokeMethod('InjectOnePoint',item.toJson().toString());
        Provider.of<UserData>(context, listen: false).setPoints([]);
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
        platform.invokeMethod('InjectOnePoint',cloneTrip.detail[index[0]].dayList[index[1]].toJson().toString());
      }
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
                        child: CachedNetworkImage(
                          imageUrl: userData.picBing != '' ? userData.picBing : tripItem.picURL,
                          fit: BoxFit.cover,
                          height: 150,
                          //placeholder: (context, url) => const CircularProgressIndicator(), // 加载中的占位符
                          errorWidget: (context, url, error) => const Icon(Icons.error),
                        ),
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
              // AlertDialog(
              //   title: const Text('完善内容'),
              //   content: StatefulBuilder(builder: (context, StateSetter setState) {           
              //     return SingleChildScrollView(
              //       child: ExpansionPanelList(
              //         elevation: 0,
              //         dividerColor: Colors.white,
              //         expandedHeaderPadding: const EdgeInsets.all(0),
              //         expansionCallback: (index, isExpanded) {
              //           setState(() {
              //             _modalIndex = index;
              //           });
              //         },
              //         children: [
              //           ExpansionPanel(
              //             canTapOnHeader: true,
              //             isExpanded: _modalIndex == 0,
              //             body: TextField(
              //               controller: _controller1,
              //               decoration: const InputDecoration(
              //                 labelText: '输入景点名字',
              //               ),
              //             ),
              //             headerBuilder: (context, isExpanded) {
              //               return ListTile(
              //                 title: const Text('名字：'),
              //                 onTap: (){
              //                   setState(() {
              //                     _modalIndex = 0;
              //                   });
              //                 },
              //               );
              //             },
              //           ),
              //           ExpansionPanel(
              //             canTapOnHeader: true,
              //             isExpanded: _modalIndex == 1,
              //             body: TextField(
              //               controller: _controller2,
              //               maxLines: 5,
              //               decoration: const InputDecoration(
              //                 labelText: '输入描述',
              //               ),
              //             ),
              //             headerBuilder: (context, isExpanded) {
              //               return ListTile(
              //                 title: const Text('描述：'),
              //                 onTap: (){
              //                   setState(() {
              //                     _modalIndex = 1;
              //                   });
              //                 },
              //               );
              //             },
              //           ),
              //           ExpansionPanel(
              //             canTapOnHeader: true,
              //             isExpanded: _modalIndex == 2,
              //             body: TextField(
              //               controller: _controller3,
              //               maxLines: 3,
              //               decoration: const InputDecoration(
              //                 labelText: '输入图片链接',
              //               ),
              //             ),
              //             headerBuilder: (context, isExpanded) {
              //               return ListTile(
              //                 title: const Text('图片链接：'),
              //                 onTap: (){
              //                   setState(() {
              //                     _modalIndex = 2;
              //                   });
              //                 },
              //               );
              //             },
              //           ),
              //         ],
              //       ),
              //     );
              //   }),
              //   actions: 
              //   [
              //     Provider.of<UserData>(context).picsFromAlbum.isEmpty
              //     ?TextButton(
              //       onPressed: addPic,
              //       child: const Text('选择图片'),
              //     )
              //     :TextButton(
              //       onPressed: upload,
              //       child: const Text('上传图片'),
              //     ),
              //     TextButton(
              //       onPressed: save,
              //       child: tripItem.nameOfScence == '' ? const Text('添加至当日行程') : const Text('保存修改'),
              //     )
              //   ]         
              // )
            );
          }
        )
        ;
      },
    );
  }

  List<dynamic> indexAndTripItem(TravelModel cloneTrip, nameOfScence) {
    DetailModel item = DetailModel();
    List index = [];
    for (int i = 0; i < cloneTrip.detail.length; i++) {
      if(cloneTrip.detail[i].dayList.isNotEmpty){
        for (int j = 0; j < cloneTrip.detail[i].dayList.length; j++) {
          if(cloneTrip.detail[i].dayList[j].nameOfScence == nameOfScence){
            item = cloneTrip.detail[i].dayList[j];
            index.add(i);
            index.add(j);
            break;
          }
        }
      }
    }
    return [item, index];
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
        AllStoryModel authorStorys = await StoryDao.fetchByAuthor(1, auth.uid);
        AllStoryModel likesStorys = await StoryDao.likeOrCollect(1, auth.uid, 'likes');
        AllStoryModel collectStorys = await StoryDao.likeOrCollect(1, auth.uid, 'comments');
        setState((){
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
    //print('--------${flatData(userData.detail).length}');
    dynamic jsonArray = flatData(userData.detail).map((i) => json.encode(i)).toList();
    String string = jsonArray.toString();
    platform.invokeMethod('InjectData',string);
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
    if (index == 2) {
      storyKey.currentState?.toTop();
    } else if (index == 1 && tripList.isNotEmpty) {
      listKey.currentState?.toTop();
    } else if (index == 0) {
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
      barrierDismissible: false, // user must tap button!
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
          onPageChanged: _onItemTapped,
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: <Widget>[
            GaodeMap(
              key: mapKey,
              domestic: inChina,
              openSnackBar: _openSnackBar, 
              points: flatData(userData.detail).map((i) => json.encode(i)).toList().toString(),
              hotelPoints: hotelData(flatData(userData.detail)).map((i) => json.encode(i)).toList().toString(),
              foodPoints: foodData(flatData(userData.detail)).map((i) => json.encode(i)).toList().toString(),
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
            ),
            Story(
              key: storyKey,
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