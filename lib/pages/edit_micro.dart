import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math';
import "package:images_picker/images_picker.dart";
import 'package:image_picker/image_picker.dart';
//import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'dart:io';
import 'package:nextsticker2/dao/newclient_dao.dart';
import 'package:nextsticker2/dao/story_dao.dart';
import 'package:qiniu_flutter_sdk/qiniu_flutter_sdk.dart';
import 'package:nextsticker2/model/travel_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class EditMicro extends StatefulWidget {
  const EditMicro({
    Key? key,
  }): super(key: key);
  @override
  EditMicroState createState() => EditMicroState();
}

class EditMicroState extends State<EditMicro> with AutomaticKeepAliveClientMixin{
  @override
  bool get wantKeepAlive => true;
  final storage = Storage();
  late PutController putController;

  final TextEditingController _controller1 = TextEditingController();
  final TextEditingController _controller2 = TextEditingController();
  List medias = [];
  List<Future>tasks = [];
  String title = '';
  String content = '';
  bool uploading = false;
  double progress = 0.0;
  @override
  void initState() {
    super.initState();
    init();
  }

  void init()async{
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String microTitle = prefs.getString('microTitle') ?? '' ;
    String microContent = prefs.getString('microContent') ?? '';
    //if(microTitle != null || microContent != null){
    setState(() {
      _controller1.text = microTitle;
      _controller2.text = microContent;
      title = microTitle;
      content = microContent;
    });
    //}
  }

  @override
  void dispose() {
    super.dispose();
    _controller1.dispose();
    _controller2.dispose();
  }

  Future startUploadToQiniu(token, path) async{
    putController = PutController();
    putController.addSendProgressListener((double percent) {
      debugPrint('已上传进度变化：已发送：$percent');
    });
    debugPrint('添加任务进度订阅');
    putController.addProgressListener((double percent) {
      setState(() {
        progress = percent;
      });
      debugPrint('任务进度变化：已发送：$percent');
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
    upload = storage.putFile(
      File(path),
      token,
      options: putOptions,
    );
    try{
      PutResponse response = await upload;
      debugPrint('上传已完成: 原始响应数据: ${ReturnBody.fromJson(response.rawData)}');
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

  void upToServer(body, fn, title, content, uid, initUserData, medias) async{
    List picArr = [];
    List localURL = [];
    for (var i = 0; i < body.length; i++) {
      picArr.add(body[i].toJson());
      localURL.add(medias[i].path);
    }
    try{
      dynamic res = await StoryDao.poMicro({
        'articleName': title,
        'articleContent': content,
        'picURL': body[0].key,
        'width': body[0].width,
        'height': body[0].height,
        'articleType': 2,
        'album': picArr,
        'localURL': localURL,
        'author': uid,
      });
      if(res != null){
        setState(() {
          uploading = false;
          Navigator.of(context).pop();
          fn('发布成功！', 1);
          initUserData(true);
        });
        clear();
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

  Future _add() async {
    List res;
    if(defaultTargetPlatform == TargetPlatform.iOS){
      res = await (ImagesPicker.pick(
        count: 9,
        pickType: PickType.image
      )) as List<dynamic>;
    } else {
      final ImagePicker picker = ImagePicker();
      res = await picker.pickMultiImage();
    }
    if(res.isNotEmpty){
      setState(() {
        medias = res;
      });
    }
  }

  List listPics(){
    List pics = [];
    if(medias.isNotEmpty){
      for(var i = 0; i < medias.length ; i++){
        pics.add(picContainer(medias[i].path, i));
      }
    }
    return pics;
  }

  void delete(index){
    setState(() {
      medias.removeAt(index);
      medias = medias;
    });
  }

  Widget picContainer(path, index){
    return 
      Stack(
        children: [
          Container(
            width: 150, 
            height: 150,
            margin: const EdgeInsets.fromLTRB(0, 0, 5, 0),
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              borderRadius:const BorderRadius.all(Radius.circular(20)),
              color: randomColor(),
            ),
            child: Image.file(
              File(path),
              width: 150,
              height: 150,
              fit: BoxFit.cover,
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

  void _submit(fn, medias, uid, initUserData)async{
    String token = await Micro.getToken('');
    setState(() {
      uploading = true;
    });
    for (var i= 0; i < medias.length; i++){
      tasks.add(startUploadToQiniu(token, medias[i].path));
    }
    List body = await Future.wait(tasks);
    upToServer(body, fn, title, content, uid, initUserData, medias);
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

  void _save(fn)async{
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('microTitle', title);
    await prefs.setString('microContent', content);
    fn('已保存草稿！', 1);
  }

  void clear()async{
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if(title == ''){
      await prefs.setString('microTitle', '');
    }
    if(content == ''){
      await prefs.setString('microContent', '');
    }
  }

  void back(openSnackBar, platform){
    if(title != '' || content != ''){
      _save(openSnackBar);
    } else {
      clear();
    }
    if(platform != null){
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
    final uid = data["uid"];
    final Function initUserData = data["initUserData"];
    return Scaffold(
      appBar: AppBar(
        title: const Text('发图文'),
        centerTitle:true,
        leading: GestureDetector(child: const Icon(Icons.arrow_back_ios),onTap: () => back(openSnackBar, platform)),
        actions:<Widget>[
          TextButton(
            onPressed: (title != '' || content != '' ? () => _save(openSnackBar) : null),
            child: Text('存草稿', style: TextStyle(color: (medias.isNotEmpty || title != '' || content != '' ?Colors.white: Colors.grey))),
          ),
          TextButton(
            onPressed: (medias.isEmpty || title == '' || content == '' || uploading ? null : () => _submit(openSnackBar, medias, uid, initUserData)),
            child: Text('发布', style: TextStyle(color: (medias.isEmpty || title == '' || content == '' ?Colors.grey: Colors.black))),
          )
        ]
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Container(
              width: MediaQuery.of(context).size.width,
              margin: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              decoration: const BoxDecoration(
                //color: Color.fromARGB(255, 218, 208, 208), 
              ),
              child: Column(children: [
                SizedBox(
                  height: 150,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ...listPics(),
                      Container(
                        width: 150, 
                        height: 150,
                        margin: const EdgeInsets.fromLTRB(0, 0, 5, 0),
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.all(Radius.circular(20)),
                          color: Colors.orange[100],
                        ),
                        child: Center(
                          child: IconButton(
                            onPressed: _add,
                            icon: const Icon(Icons.add_circle_outline, color: Colors.black, size: 30,),
                            color: theme.colorScheme.onSecondary,
                          )
                        ),
                      ),
                    ],
                  ),
                ),
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
                  decoration:const InputDecoration(
                    hintText: '你的分享：',
                    border:InputBorder.none
                  ),
                  maxLines: 10
                ),
                const Divider()
              ]),
            ),
          ),
          uploading == true
          ?const Center(
            child: CircularProgressIndicator(),
          )
          :Container(),
          uploading == true
          ?Center(
            child: Text('${progress * 100.round()}%', style: const TextStyle(color: Colors.grey),)
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