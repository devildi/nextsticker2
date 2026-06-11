import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math';
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
  
  VideoPlayerController? _controller;
  final TextEditingController _controller1 = TextEditingController();
  final TextEditingController _controller2 = TextEditingController();
  List<XFile> medias = [];
  Uint8List? picData;
  
  String title = '';
  String content = '';
  bool uploading = false;
  
  // Progress tracking
  double videoProgress = 0.0;
  double thumbProgress = 0.0;

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    _controller?.dispose();
    super.dispose();
  }

  // flag: true for bytes (thumbnail), false for file (video)
  Future<ReturnBody?> startUploadToQiniu(String token, dynamic source, bool isThumbnail) async{
    PutController putController = PutController();
    
    putController.addProgressListener((double percent) {
      if(mounted) {
        setState(() {
          if (isThumbnail) {
            thumbProgress = percent;
          } else {
            videoProgress = percent;
          }
        });
      }
    });

    final putOptions = PutOptions(
      controller: putController
    );
    
    Future<PutResponse> upload;
    if(isThumbnail){
      // source is Uint8List
      upload = storage.putBytes(
        source,
        token,
        options: putOptions,
      );
    }else{
      // source is path String
      upload = storage.putFile(
        File(source),
        token,
        options: putOptions,
      );
    }
    
    try{
      PutResponse response = await upload;
      debugPrint('上传完成 (${isThumbnail ? "缩略图" : "视频"}): ${response.key}');
      
      // For video, we will use local dimensions in the final step, 
      // but we return the body here as per protocol.
      return ReturnBody.fromJson(response.rawData);
    } catch(error){
      debugPrint('上传失败: ${error.toString()}');
      return null;
    }
  }

  void upToServer(ReturnBody videoBody, ReturnBody thumbBody, double height, double width, String title, String content, dynamic uid, Function initUserData) async{
    try{
      dynamic res = await StoryDao.poMicro({
        'articleName': title,
        'articleContent': content,
        'picURL': thumbBody.key,
        'videoURL': videoBody.key,
        'width': width.toString(),
        'height': height.toString(),
        'articleType': 3,
        'author': uid,
      });
      
      if(mounted) {
        if(res != null){
          setState(() {
            uploading = false;
          });
          Navigator.of(context).pop();
          initUserData(true);
        } else {
           setState(() {
            uploading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('发布失败，请重试')),
          );
        }
      }
    }catch(err){
      debugPrint(err.toString());
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
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    
    if(video != null){
      // Dispose old controller if exists
      _controller?.dispose();
      
      final controller = VideoPlayerController.file(File(video.path));
      await controller.initialize();
      controller.setLooping(true);
      controller.setVolume(1.0); 
      controller.play();

      final uint8list = await VideoThumbnail.thumbnailData(
        video: video.path,
        imageFormat: ImageFormat.JPEG,
        quality: 50, 
      );

      setState(() {
        medias = [video];
        picData = uint8list;
        _controller = controller;
      });
    }
  }

  void delete(){
    _controller?.dispose();
    setState(() {
      medias = [];
      picData = null;
      _controller = null;
    });
  }

  Widget picContainer(){
    if (_controller == null || !_controller!.value.isInitialized) {
      return Container();
    }
    
    return Stack(
      children: [
        Container(
          width: MediaQuery.of(context).size.width - 40, 
          height: (MediaQuery.of(context).size.width - 40) / _controller!.value.aspectRatio,
          margin: const EdgeInsets.fromLTRB(0, 0, 5, 0),
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(20)),
            color: Colors.black,
          ),
          child: AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          )
        ),
        Positioned(
          top: 0,
          right: 5,
          child: IconButton(
            onPressed: delete,
            icon: const Icon(Icons.clear, color: Colors.white, size: 30,)
          ),
        )
      ],
    );
  }

  void _submit(dynamic uid, Function initUserData)async{
    if (medias.isEmpty || picData == null || _controller == null) return;
    
    FocusScope.of(context).unfocus();
    
    setState(() {
      uploading = true;
      videoProgress = 0.0;
      thumbProgress = 0.0;
    });

    try {
      String token = await Micro.getToken('3'); 
      
      // Parallel uploads
      var videoTask = startUploadToQiniu(token, medias[0].path, false);
      var thumbTask = startUploadToQiniu(token, picData, true);
      
      List<ReturnBody?> results = await Future.wait([videoTask, thumbTask]);
      
      ReturnBody? videoRes = results[0];
      ReturnBody? thumbRes = results[1];

      if (videoRes != null && thumbRes != null) {
        upToServer(videoRes, thumbRes, _controller!.value.size.height, _controller!.value.size.width, title, content, uid, initUserData);
      } else {
         if(mounted) {
            setState(() {
              uploading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(backgroundColor: Colors.red, content: Text('上传失败，请重试')),
            );
         }
      }
      
    } catch (e) {
      debugPrint("Error: $e");
      if(mounted) {
        setState(() {
          uploading = false;
        });
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: Colors.red, content: Text('发生错误，请重试')),
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

  void back(){
    Navigator.of(context).pop();
  }
  
  // Weighted progress: Video 95%, Thumb 5%
  double get totalProgress {
    return (videoProgress * 0.95) + (thumbProgress * 0.05);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final dynamic data = ModalRoute.of(context)?.settings.arguments;
    // final Function openSnackBar = data["openSnackBar"]; // Unused locally
    // final platform = data["platform"];
    // final socket = data != null ? data["socket"] : null; 
    final uid = data != null ? data["uid"] : null;
    final Function initUserData = data != null ? data["initUserData"] ?? (val){} : (val){};
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('发视频'),
        centerTitle:true,
        leading: GestureDetector(onTap: back, child: const Icon(Icons.arrow_back_ios)),
        actions:<Widget>[
          TextButton(
            onPressed: (medias.isEmpty || title == '' || content == '' || uploading ? null : () => _submit(uid, initUserData)),
            child: Text('发布', style: TextStyle(color: (medias.isEmpty|| title == '' || content == '' ?Colors.grey: Colors.black))),
          )
        ]
      ),
      body: Stack(
        children: [
          Container(
            width: MediaQuery.of(context).size.width,
            margin: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
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
                      onPressed: _add,
                      icon: const Icon(Icons.add_circle_outline, color: Colors.black, size: 30,),
                      color: theme.colorScheme.onSecondary,
                    )
                  ),
                ),
              )
              : picContainer(),
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