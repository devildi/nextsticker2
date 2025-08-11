import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:nextsticker2/dao/newclient_dao.dart';

class NewClient extends StatefulWidget {
  const NewClient({
    Key? key,
  }):super(key: key);

  @override
  NewClientState createState() => NewClientState();
}

class NewClientState extends State<NewClient> {
  
  late VideoPlayerController _controller;
  final TextEditingController _controller1 = TextEditingController();
  final TextEditingController _controller2= TextEditingController();

  String wechat = '';
  String destination = '';

  @override
  void initState() {
    super.initState();
    //_controller = VideoPlayerController.network(vedioURL)
    _controller = VideoPlayerController.asset("assets/video.mp4")
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

  void _submit(Function func)async {
    try{
      Navigator.of(context).pop();
      String res = await ClientDao.create({
        'destination': _controller1.text,
        'wechat': _controller2.text
      });
      if(res != ''){
        _controller.dispose();
        func('已提交，请耐心等待!', 2);
      } else {
        func('系统错误，稍后请重试！', 2);
      }
    } catch(err){
      func('网络错误，请重试！', 2);
    }
  }

  void _wechatChanged(String str){
    setState((){
      wechat = str;
    });
  }

  void _destinationChanged(String str){
    setState((){
      destination = str;
    });
  }

  void _back(){
    _controller.pause();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final Function openSnackBar = (ModalRoute.of(context)?.settings.arguments) as Function;
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
                child: 
                  AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
              ),
            )
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 20,
            child: GestureDetector(onTap: _back, child: const Icon(Icons.arrow_back_ios, color: Colors.white))
          ),
          Positioned(
            left: 18.0,
            right: 18,
            top: 90,
            child: SizedBox(
              height: 50,
              child: TextField(
                onChanged: _destinationChanged,
                controller: _controller1,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  fillColor: Color(0x30cccccc),
                  filled: true,
                  contentPadding: EdgeInsets.fromLTRB(10, 0, 0, 0),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0x00FF0000)),
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                  hintText: '要去哪里：',
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
                onChanged: _wechatChanged,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.fromLTRB(10, 0, 0, 0),
                  fillColor: Color(0x30cccccc),
                  filled: true,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0x00FF0000)),
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                  hintText: '微信号：',
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
                  onPressed: (destination == '' || wechat == ''
                  ? null
                  : (){_submit(openSnackBar);}),
                  child: const Text('我要定制', style: TextStyle(color: Colors.white,fontSize: 20), textDirection: TextDirection.ltr,),
                ),
              )
            )
          ),
        ],
      ),
    );
  }
}