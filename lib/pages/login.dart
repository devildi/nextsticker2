import 'package:flutter/material.dart';
import 'package:nextsticker2/model/travel_model.dart';
import 'package:video_player/video_player.dart';
import 'package:nextsticker2/dao/newclient_dao.dart';
import 'package:shared_preferences/shared_preferences.dart';
//const vedioURL = 'https://cdn.moji.com/websrc/video/video621.mp4';
import 'package:provider/provider.dart';
import 'package:nextsticker2/store/store.dart';
import 'dart:convert';

class Login extends StatefulWidget {
  const Login({
    Key? key,
  }): super(key: key);
  @override
  LoginState createState() => LoginState();
}

class LoginState extends State<Login> {
  
  late VideoPlayerController _controller;
  final TextEditingController _controller1 = TextEditingController();
  final TextEditingController _controller2= TextEditingController();

  String userName = '';
  String passWord = '';

  @override
  void initState() {
    super.initState();
    //_controller = VideoPlayerController.network(vedioURL)
    _controller = VideoPlayerController.asset("assets/video1.mp4")
    ..initialize().then((_) {
      // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
      setState(() {});
      _controller.play();
      _controller.setLooping(true);
      _controller.setVolume(0.0);
    });
  }
  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
    _controller1.dispose();
    _controller2.dispose();
  }

  bool validate(input){
    return input?.isNotEmpty ?? false;
  }

  void _submit(Function func, String from, platform ,socket, initUserData)async {
    try{
      AuthModel res = await LoginDao.login({
        'name': _controller1.text,
        'password': _controller2.text,
        'from': 'app'
      });
      if(res.name != ''){
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth', json.encode(res));
        if (!context.mounted) return;
        Provider.of<UserData>(context, listen: false).setAuth(res);
        initUserData(true);
        //_controller.dispose();
        switch(from) {
          case "editMicro":
            func('登录成功！', 2);
            Navigator.pushNamed(context, from, arguments:{
              "openSnackBar": func,
              "platform": platform,
              "socket": socket
            });
            break;
          case "editMovie":
            func('登录成功！', 2);
            Navigator.pushNamed(context, from, arguments:{
              "openSnackBar": func,
              "platform": platform,
              "socket": socket
            });
            break;
          case "chat":
            func('登录成功！', 2);
            Navigator.pushNamed(context, from, arguments:{
              "openSnackBar": func,
              "platform": platform,
              "socket": socket
            });
            break;
          default:
            func('登录成功！', 2);
            Navigator.of(context).pop('sucess');
        }
      } else {
        func('用户名或密码错误！', 2);
        //Navigator.of(context).pop();
      }
    } catch(err){
      debugPrint(err.toString());
      func('网络错误，请重试！', 2);
    }
  }

  void _userNameChanged(String str){
    setState((){
      userName = str;
    });
  }

  void _passWordChanged(String str){
    setState((){
      passWord = str;
    });
  }

  void _back(){
    //_controller.pause();
    Navigator.of(context).pop();
  }

  void _register(fn, fn2){
    //_controller.pause();
    Navigator.of(context).pushReplacementNamed('register', arguments:{
      "fn": fn,
      "initUserData": fn2
    });
  }

  @override
  Widget build(BuildContext context) {
    final dynamic data = ModalRoute.of(context)?.settings.arguments;
    final Function openSnackBar = data["fn"];
    final String from = data["from"] ?? '';
    final platform = data["platform"];
    final socket = data["socket"];
    final Function initUserData = data["initUserData"];
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ClipRect(
            //height: MediaQuery.of(context).size.height,
            //width: MediaQuery.of(context).size.width,
            child: Transform.scale(
              scale: _controller.value.aspectRatio /
                MediaQuery.of(context).size.aspectRatio,
              child: Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              ),
            )
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 20,
            child: GestureDetector(onTap: _back, child: const Icon(Icons.close, color: Colors.white), )
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top,
            right: 20,
            child: GestureDetector(onTap: () => _register(openSnackBar, initUserData), child: const Text('去注册', style: TextStyle(color: Colors.white)), )
          ),
          Positioned(
            left: 18.0,
            right: 18,
            top: 90,
            child: SizedBox(
              height: 50,
              child: TextField(
                onChanged: _userNameChanged,
                controller: _controller1,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  fillColor: Color(0x30cccccc),
                  filled: true,
                  contentPadding: EdgeInsets.fromLTRB(10, 0, 0, 0),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0x00FF0000)),
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                  hintText: '用户名：',
                  hintStyle: TextStyle(color: Colors.white70),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0x00000000)),
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                ),
              ),
            )
          ),
          Positioned(
            left: 18.0,
            right: 18,
            top: 150,
            child: SizedBox(
              height: 50,
              child: TextField(
                controller: _controller2,
                onChanged: _passWordChanged,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.fromLTRB(10, 0, 0, 0),
                  fillColor: Color(0x30cccccc),
                  filled: true,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0x00FF0000)),
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                  hintText: '密码：',
                  hintStyle: TextStyle(color: Colors.white70),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0x00000000)),
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                ),
              ),
            )
          ),
          Positioned(
            left: 18.0,
            right: 18,
            bottom: 15,
            child: SizedBox(
              height: 50,
              child: ClipRRect(
                borderRadius:BorderRadius.circular(10),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  onPressed: (userName == '' || passWord == ''
                  ? null
                  : (){_submit(openSnackBar, from, platform, socket, initUserData);}),
                  child: const Text('登录', style: TextStyle(color: Colors.white,fontSize: 20), textDirection: TextDirection.ltr,),
                ),
              )
            )
          ),
        ],
      ),
    );
  }
}