import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math';
import "package:images_picker/images_picker.dart";
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:nextsticker2/dao/newclient_dao.dart';
import 'package:nextsticker2/dao/story_dao.dart';
import 'package:qiniu_flutter_sdk/qiniu_flutter_sdk.dart';
import 'package:nextsticker2/model/travel_model.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:flutter/foundation.dart';

class EditMovie extends StatefulWidget {
  const EditMovie({
    Key? key,
  }): super(key: key);
  @override
  EditMovieState createState() => EditMovieState();
}

class EditMovieState extends State<EditMovie> with AutomaticKeepAliveClientMixin{
  @override
  bool get wantKeepAlive => true;
  final storage = Storage();
  late PutController putController;

  late VideoPlayerController _controller;
  final TextEditingController _controller1 = TextEditingController();
  final TextEditingController _controller2 = TextEditingController();
  List medias = [];
  dynamic picData;
  List<Future>tasks = [];
  String title = '';
  String content = '';
  bool uploading = false;
  double progress = 0.0;

  @override
  void dispose() {
    super.dispose();
    _controller1.dispose();
    _controller2.dispose();
    _controller.dispose();
  }

  Future startUploadToQiniu(token, path, flag) async{
    debugPrint('创建 PutController');
    putController = PutController();
    debugPrint('添加实际发送进度订阅');
    putController.addSendProgressListener((double percent) {
      debugPrint('已上传进度变化：已发送：$percent');
    });
    debugPrint('添加任务进度订阅');
    putController.addProgressListener((double percent) {
      debugPrint('任务进度变化：已发送：$percent');
      setState(() {
        progress = percent;
      });
    });
    debugPrint('添加状态订阅');
    putController.addStatusListener((StorageStatus status) {
      debugPrint('状态变化: 当前任务状态：$status');
    });
    debugPrint('开始上传文件');
    final putOptions = PutOptions(
      controller: putController
    );
    Future<PutResponse> upload;
    if(flag){
      upload = storage.putBytes(
        path,
        token,
        options: putOptions,
      );
    }else{
      upload = storage.putFile(
        File(path),
        token,
        options: putOptions,
      );
    }
    try{
      PutResponse response = await upload;
      debugPrint('上传已完成: 原始响应数据: ${response.rawData}');
      debugPrint('------------------------');
      ReturnBody body = ReturnBody.fromJson(response.rawData);
      return body;
    } catch(error){
      
      if (error is StorageError) {
        switch (error.type) {
          case StorageErrorType.CONNECT_TIMEOUT:
            debugPrint('发生错误: 连接超时');
            break;
          case StorageErrorType.SEND_TIMEOUT:
            debugPrint('发生错误: 发送数据超时');
            break;
          case StorageErrorType.RECEIVE_TIMEOUT:
            debugPrint('发生错误: 响应数据超时');
            break;
          case StorageErrorType.RESPONSE:
            debugPrint('发生错误: ${error.message}');
            break;
          case StorageErrorType.CANCEL:
            debugPrint('发生错误: 请求取消');
            break;
          case StorageErrorType.UNKNOWN:
            debugPrint('发生错误: 未知错误');
            break;
          case StorageErrorType.NO_AVAILABLE_HOST:
            debugPrint('发生错误: 无可用 Host');
            break;
          case StorageErrorType.IN_PROGRESS:
            debugPrint('发生错误: 已在队列中');
            break;
        }
      } else {
        debugPrint('发生错误: ${error.toString()}');
      }
      debugPrint('------------------------');
    }
  }

  void upToServer(body, fn, height, width, title, content, uid, initUserData) async{
    List picArr = [];
    for (var i = 0; i < body.length; i++) {
      picArr.add(body[i].toJson());
    }
    try{
      dynamic res = await StoryDao.poMicro({
        'articleName': title,
        'articleContent': content,
        'picURL': body[1].key,
        'videoURL': body[0].key,
        'width': width,
        'height': height,
        'articleType': 3,
        'author': uid,
      });
      if(res != null){
        setState(() {
          uploading = false;
          Navigator.of(context).pop();
          fn('发布成功！请下拉刷新！', 2);
          initUserData(true);
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

  Future _add(platform) async {
    List res = [];
    if(defaultTargetPlatform == TargetPlatform.iOS){
      res = await (ImagesPicker.pick(
        count: 1,
        pickType: PickType.video
      )) as List<dynamic>;
    }else{
      final ImagePicker picker = ImagePicker();
      final XFile video1 = await (picker.pickVideo(source: ImageSource.gallery)) as XFile;
      debugPrint(video1.path);
      res.add(video1);
    } 
    if(res.isNotEmpty){
      _controller = VideoPlayerController.file(File(res[0].path))
      ..initialize().then((_) {
        setState(() {
         
        });
        _controller.play();
        _controller.setLooping(true);
        _controller.setVolume(0.0);
      });
      final uint8list = await VideoThumbnail.thumbnailData(
        video: res[0].path,
        imageFormat: ImageFormat.JPEG,
        quality: 25,
      );
      setState(() {
        medias = res;
        picData = uint8list;
      });
    }
  }

  void delete(index){
    setState(() {
      medias.removeAt(index);
      medias = medias;
    });
  }

  Widget picContainer(index){
    return 
      Stack(
        children: [
          Container(
            width: MediaQuery.of(context).size.width - 40, 
            height: (MediaQuery.of(context).size.width - 40) / _controller.value.aspectRatio,
            margin: const EdgeInsets.fromLTRB(0, 0, 5, 0),
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(20)),
              color: randomColor(),
            ),
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            )
          ),
          Positioned(
            top: 0,
            right: 5,
            child: IconButton(
              onPressed: () => delete(index),
              icon: const Icon(Icons.clear, color: Colors.white, size: 30,)
            ),
          )
        ],
      );
  }

  void _submit(fn, uid, initUserData)async{
    String token = await Micro.getToken('3');
    setState(() {
      uploading = true;
    });
    tasks.add(startUploadToQiniu(token, medias[0].path, false));
    tasks.add(startUploadToQiniu(token, picData, true));
    List body = await Future.wait(tasks);
    upToServer(body, fn, _controller.value.size.height, _controller.value.size.width, title, content, uid, initUserData);
  }

  void _titleChanged(String str){
    setState((){
      title = str;
    });
  }

  void _contentChanged(String str){
    setState((){
      content = str;
    });
  }

  void back(socket){
    if(socket != null){
      Navigator.of(context).pop();
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final dynamic data = ModalRoute.of(context)?.settings.arguments;
    final Function openSnackBar = data["openSnackBar"];
    final platform = data["platform"];
    final socket = data["socket"];
    final uid = data["uid"];
    final Function initUserData = data["initUserData"];
    return Scaffold(
      appBar: AppBar(
        title: const Text('发视频'),
        centerTitle:true,
        leading: GestureDetector(child: const Icon(Icons.arrow_back_ios),onTap: () => back(socket)),
        actions:<Widget>[
          TextButton(
            onPressed: (medias.isEmpty || title == '' || content == '' || uploading ? null : () => _submit(openSnackBar, uid, initUserData)),
            child: Text('发布', style: TextStyle(color: (medias.isEmpty|| title == '' || content == '' ?Colors.grey: Colors.white))),
          )
        ]
      ),
      body: Stack(
        children: [
          Container(
            width: MediaQuery.of(context).size.width,
            margin: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            decoration: const BoxDecoration(
              //color: Color.fromARGB(255, 218, 208, 208), 
            ),
            child: ListView(children: [
              medias.isEmpty
              ?SizedBox(
                height: 150,
                child: Container(
                  width: MediaQuery.of(context).size.width - 40, 
                  height: (MediaQuery.of(context).size.width - 40) * 9 /16,
                  margin: const EdgeInsets.fromLTRB(0, 0, 5, 0),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(20)),
                    color: Colors.yellow[100],
                  ),
                  child: Center(
                    child: IconButton(
                      onPressed: () => _add(platform),
                      icon: const Icon(Icons.add_circle_outline, color: Colors.black, size: 30,),
                      color: theme.colorScheme.onSecondary,
                    )
                  ),
                ),
              )
              :picContainer(0),
              TextField(
                onChanged: _titleChanged,
                controller: _controller1,
                decoration:const InputDecoration(
                  hintText: '标题：',
                  border:InputBorder.none
                )
              ),
              const Divider(),
              TextField(
                onChanged: _contentChanged,
                controller: _controller2,
                decoration: const InputDecoration(
                  hintText: '你的分享：',
                  border:InputBorder.none
                ),
                maxLines: 10
              ),
              const Divider()
            ]),
          ),
          uploading == true
          ?const Center(
            child: CircularProgressIndicator(),
          )
          :Container(),
          uploading == true
          ?Center(
            child: Text('$progress%', style: const TextStyle(color: Colors.grey),)
          )
          :Container(),
          uploading == true
          ?LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: Colors.grey,
            valueColor: const AlwaysStoppedAnimation(Colors.blue)
          )
          :Container(),
        ],
      )
    );
  }
}

Color randomColor(){
  List colors = [Colors.red[100], Colors.green[100], Colors.yellow[100], Colors.orange[100]];
  Random random = Random();
  return colors[random.nextInt(4)];
}