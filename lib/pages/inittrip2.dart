import 'package:flutter/material.dart';
import 'package:nextsticker2/model/travel_model.dart';
import 'package:provider/provider.dart';
import 'package:nextsticker2/store/store.dart';
import 'package:nextsticker2/pages/map_design.dart';
import 'package:image_picker/image_picker.dart';
import "package:images_picker/images_picker.dart";
import 'package:flutter/foundation.dart';
import 'package:qiniu_flutter_sdk/qiniu_flutter_sdk.dart';
import 'dart:io';
import 'package:nextsticker2/dao/newclient_dao.dart';

class InitTrip2 extends StatefulWidget {
  final dynamic platform;
  final String tripName;
  // final String designer;
  final String domestic;
  //final String uid;
  const InitTrip2({
    required this.platform,
    required this.tripName,
    //required this.designer,
    required this.domestic,
    //required this.uid,
    Key? key,
    }): super(key: key);
  @override
  InitTripState2 createState() => InitTripState2();
}

class InitTripState2 extends State<InitTrip2> {
  // final TextEditingController _controller5 = TextEditingController();
  // final TextEditingController _controller6 = TextEditingController();
  // final TextEditingController _controller7 = TextEditingController();
  final TextEditingController _controller8 = TextEditingController();
  final storage = Storage();
  late PutController putController;

  // String city = 'tttt';
  // String country= 'tttt';
  // String tags= 'tt';
  String cover= '';
  
  List medias = [];
  double progress = 0.0;
  bool uploading = false;

  // void cityChanged(String str){
  //   setState((){
  //     city = str;
  //   });
  // }

  // void countryChanged(String str){
  //   setState((){
  //     country = str;
  //   });
  // }

  // void tagsChanged(String str){
  //   setState((){
  //     tags = str;
  //   });
  // }

  void coverChanged(String str){
    setState((){
      cover = str;
    });
  }

  @override
  void initState() {
    super.initState();
  }

  void next()async{
    //行程初始化模版
    TravelModel trip = TravelModel(
      //uid: widget.uid,
      tripName: widget.tripName,
      //designer: widget.designer,
      detail: [DayDetail(dayList: [])],
      domestic: int.parse(widget.domestic == '' ? '1' : widget.domestic) ,
      // city: city,
      // country: country,
      // tags: tags,
      //cover: _controller8.text
      cover: ''
    );
    Provider.of<UserData>(context, listen: false).setCloneData(trip);
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => MapDesign(
        platform: widget.platform,
        tripData: trip,
        setTripData: (){},
      )
    ));
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

  Future _add() async {
    List res;
    if(defaultTargetPlatform == TargetPlatform.iOS){
      res = await (ImagesPicker.pick(
        count: 1,
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

  void upload() async{
    setState(() {
      uploading = true;
      up();
    });
  }

  void up()async{
    try{
      String token = await Micro.getToken('');
      ReturnBody body = await startUploadToQiniu(token, medias[0].path);
      _controller8.text = 'http://nextsticker.top/${body.key}';
      setState(() {
        cover = 'http://nextsticker.top/${body.key}';
        uploading = false;
        medias = [];
      });
    } catch(err){
      debugPrint(err.toString());
      setState(() {
        uploading = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.blue, content: Text('网络错误，请稍后再试！', textAlign: TextAlign.center)),
        );
      });
    }
   
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('完善信息'),
        centerTitle:true,
        actions: [
          //city != '' && country != '' && cover != '' && tags != ''
          TextButton(
            onPressed: next,
            child: const Text('新建行程', style: TextStyle(color: Colors.black)),
          )
          // :TextButton(
          //   onPressed: (){},
          //   child: const Text('新建行程', style: TextStyle(color: Colors.grey)),
          // )
        ]
      ),
      body: Column(children: [
        // Padding(
        //   padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
        //   child: SizedBox(
        //     height: 50,
        //     child: TextField(
        //       onChanged: cityChanged,
        //       controller: _controller5,
        //       style: const TextStyle(color: Colors.black),
        //       decoration: const InputDecoration(
        //         fillColor: Color(0x30cccccc),
        //         filled: true,
        //         contentPadding: EdgeInsets.fromLTRB(10, 0, 0, 0),
        //         enabledBorder: OutlineInputBorder(
        //           borderSide: BorderSide(color: Color(0x00FF0000)),
        //           borderRadius: BorderRadius.all(Radius.circular(10))),
        //         hintText: '城市（英文/分割）',
        //         hintStyle: TextStyle(color: Colors.grey),
        //         focusedBorder: OutlineInputBorder(
        //           borderSide: BorderSide(color: Color(0x00000000)),
        //           borderRadius: BorderRadius.all(Radius.circular(10))),
        //       ),
        //     ),
        //   ),
        // ),
        // Padding(
        //   padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
        //   child: SizedBox(
        //     height: 50,
        //     child: TextField(
        //       onChanged: countryChanged,
        //       controller: _controller6,
        //       style: const TextStyle(color: Colors.black),
        //       decoration: const InputDecoration(
        //         fillColor: Color(0x30cccccc),
        //         filled: true,
        //         contentPadding: EdgeInsets.fromLTRB(10, 0, 0, 0),
        //         enabledBorder: OutlineInputBorder(
        //           borderSide: BorderSide(color: Color(0x00FF0000)),
        //           borderRadius: BorderRadius.all(Radius.circular(10))),
        //         hintText: '国家（英文/分割）',
        //         hintStyle: TextStyle(color: Colors.grey),
        //         focusedBorder: OutlineInputBorder(
        //           borderSide: BorderSide(color: Color(0x00000000)),
        //           borderRadius: BorderRadius.all(Radius.circular(10))),
        //       ),
        //     ),
        //   ),
        // ),
        // Padding(
        //   padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
        //   child: SizedBox(
        //     height: 50,
        //     child: TextField(
        //       onChanged: tagsChanged,
        //       controller: _controller7,
        //       style: const TextStyle(color: Colors.black),    
        //       decoration: const InputDecoration(
        //         fillColor: Color(0x30cccccc),
        //         filled: true,
        //         contentPadding: EdgeInsets.fromLTRB(10, 0, 0, 0),
        //         enabledBorder: OutlineInputBorder(
        //           borderSide: BorderSide(color: Color(0x00FF0000)),
        //           borderRadius: BorderRadius.all(Radius.circular(10))),
        //         hintText: '标签（英文/分割）',
        //         hintStyle: TextStyle(color: Colors.grey),
        //         focusedBorder: OutlineInputBorder(
        //           borderSide: BorderSide(color: Color(0x00000000)),
        //           borderRadius: BorderRadius.all(Radius.circular(10))),
        //       ),
        //     ),
        //   ),
        // ),
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
          child: SizedBox(
            height: 50,
            child: TextField(
              onChanged: coverChanged,
              controller: _controller8,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                suffix: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    medias.isEmpty
                    ?GestureDetector(
                      onTap: _add,
                      child: const Text('选择本地图片', style: TextStyle(color: Colors.black))
                    )
                    :GestureDetector(
                      onTap: upload,
                      child: const Text('上传图片', style: TextStyle(color: Colors.black))
                    ),
                    const SizedBox(width: 10)
                  ],
                ),
                fillColor: const Color(0x30cccccc),
                filled: true,
                contentPadding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0x00FF0000)),
                  borderRadius: BorderRadius.all(Radius.circular(10))),
                hintText: '封面',
                hintStyle: const TextStyle(color: Colors.grey),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0x00000000)),
                  borderRadius: BorderRadius.all(Radius.circular(10))),
              ),
            ),
          ),
        ),
        uploading == true
        ?const Center(
          child: CircularProgressIndicator(),
        )
        :Container(),
      ],)
    );
  }
}