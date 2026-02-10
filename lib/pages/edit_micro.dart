import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:image_picker/image_picker.dart';
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

  final TextEditingController _controller1 = TextEditingController();
  final TextEditingController _controller2 = TextEditingController();
  List<XFile> medias = [];
  String title = '';
  String content = '';
  bool uploading = false;
  // Track progress for each file index
  Map<int, double> progressMap = {};

  @override
  void initState() {
    super.initState();
    init();
  }

  void init()async{
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? microTitle = prefs.getString('microTitle');
    String? microContent = prefs.getString('microContent');
    
    setState(() {
      _controller1.text = microTitle ?? '';
      _controller2.text = microContent ?? '';
      title = microTitle ?? '';
      content = microContent ?? '';
    });
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    super.dispose();
  }

  // Returns null if upload fails
  Future<ReturnBody?> startUploadToQiniu(String token, String path, int index) async{
    // Create a local controller for each upload task
    PutController putController = PutController();
    
    putController.addProgressListener((double percent) {
       if (mounted) {
         setState(() {
           progressMap[index] = percent;
         });
       }
    });

    debugPrint('开始上传文件: $path');
    final putOptions = PutOptions(
      controller: putController
    );
    
    try{
      // Get image dimensions locally
      File file = File(path);
      var bytes = await file.readAsBytes();
      var decodedImage = await decodeImageFromList(bytes);

      PutResponse response = await storage.putFile(
        file,
        token,
        options: putOptions,
      );
      debugPrint('上传已完成: ${response.key}');
      
      return ReturnBody(
        width: decodedImage.width.toString(),
        height: decodedImage.height.toString(),
        key: response.key ?? '',
        mimeType: response.rawData['mimeType'] ?? '',
      );
    } catch(error){
      debugPrint('上传失败: $path');
      if (error is StorageError) {
        debugPrint('StorageError: ${error.type} - ${error.message}');
      } else {
        debugPrint('Error: $error');
      }
      return null;
    }
  }

  void upToServer(List<ReturnBody> body, Function fn, String title, String content, dynamic uid, Function initUserData) async{
    List<Map<String, dynamic>> picArr = body.map((e) => e.toJson()).toList();
    
    try{
      if (body.isEmpty) return;
      
      dynamic res = await StoryDao.poMicro({
        'articleName': title,
        'articleContent': content,
        'picURL': body[0].key,
        'width': body[0].width,
        'height': body[0].height,
        'articleType': 2,
        'album': picArr,
        'author': uid,
      });
      
      if(mounted) {
        if(res != null){
          clear();
          setState(() {
            uploading = false;
          });
          Navigator.of(context).pop();
          fn('发布成功！', 1);
          initUserData(true);
        } else {
           setState(() {
            uploading = false;
          });
        }
      }
    }catch(err){
      debugPrint("发布失败: $err");
      if(mounted) {
        setState(() {
          uploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.red, content: Text('网络错误，发布失败！', textAlign: TextAlign.center)),
        );
      }
    }
  }

  Future _add() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> res = await picker.pickMultiImage();
    
    if(res.isNotEmpty){
      setState(() {
        medias.addAll(res);
      });
    }
  }

  List<Widget> listPics(){
    List<Widget> pics = [];
    for(var i = 0; i < medias.length ; i++){
      pics.add(picContainer(medias[i].path, i));
    }
    return pics;
  }

  void delete(int index){
    setState(() {
      medias.removeAt(index);
    });
  }

  Widget picContainer(String path, int index){
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

  void _submit(Function fn, List<XFile> medias, dynamic uid, Function initUserData)async{
    FocusScope.of(context).unfocus();
    
    setState(() {
      uploading = true;
      progressMap.clear();
      // Initialize progress for all files to 0
      for(int i=0; i<medias.length; i++) {
        progressMap[i] = 0.0;
      }
    });

    try {
      String token = await Micro.getToken('');
      List<Future<ReturnBody?>> tasks = [];
      
      for (var i= 0; i < medias.length; i++){
        tasks.add(startUploadToQiniu(token, medias[i].path, i));
      }
      
      List<ReturnBody?> results = await Future.wait(tasks);
      
      // Filter out nulls (failed uploads)
      List<ReturnBody> successfulUploads = results.whereType<ReturnBody>().toList();
      
      if (successfulUploads.length != medias.length) {
         if(mounted) {
            setState(() {
              uploading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.red, 
                content: Text('部分图片上传失败 (${medias.length - successfulUploads.length}张失败)，请重试', textAlign: TextAlign.center)
              ),
            );
         }
         return;
      }

      upToServer(successfulUploads, fn, title, content, uid, initUserData);
      
    } catch (e) {
      debugPrint("Error in _submit: $e");
      if(mounted) {
        setState(() {
          uploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(backgroundColor: Colors.red, content: Text('发生错误，请重试', textAlign: TextAlign.center)),
        );
      }
    }
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

  void _save(Function fn)async{
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('microTitle', title);
    await prefs.setString('microContent', content);
    fn('已保存草稿！', 1);
  }

  void clear()async{
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('microTitle', '');
    await prefs.setString('microContent', '');
    // Also clear text controllers if needed, but not strictly required if navigating away
  }

  void back(Function openSnackBar){
    if(title != '' || content != ''){
      _save(openSnackBar);
    } else {
      clear();
    }
    // Simplified navigation
    Navigator.of(context).pop();
  }

  double get totalProgress {
    if (medias.isEmpty) return 0.0;
    if (progressMap.isEmpty) return 0.0;
    
    double total = 0.0;
    progressMap.forEach((key, value) {
      total += value;
    });
    return total / medias.length;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final dynamic data = ModalRoute.of(context)?.settings.arguments;
    // Handle case where arguments might be null or structure is different
    final Function openSnackBar = data != null ? data["openSnackBar"] ?? (str, dur){} : (str, dur){};
    
    final uid = data != null ? data["uid"] : null;
    final Function initUserData = data != null ? data["initUserData"] ?? (val){} : (val){};
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('发图文'),
        centerTitle:true,
        leading: GestureDetector(
          child: const Icon(Icons.arrow_back_ios),
          onTap: () => back(openSnackBar)
        ),
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
          if (uploading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     SizedBox(
                       width: 200,
                       child: LinearProgressIndicator(
                         value: totalProgress,
                         backgroundColor: Colors.grey,
                         valueColor: const AlwaysStoppedAnimation(Colors.blue),
                       ),
                     ),
                     const SizedBox(height: 16),
                     Text("上传中 ${(totalProgress * 100).toInt()}%", style: const TextStyle(color: Colors.white))
                  ],
                ),
              ),
            ),
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