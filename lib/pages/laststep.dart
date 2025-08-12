import 'package:flutter/material.dart';
import 'package:nextsticker2/model/travel_model.dart';
import 'package:nextsticker2/dao/travel_dao.dart';
import 'package:provider/provider.dart';
import 'package:nextsticker2/store/store.dart';

class LastStep extends StatefulWidget {
  final dynamic platform;
  final TravelModel trip;
  final Function save;
  const LastStep({
    required this.platform,
    required this.trip,
    required this.save,
    Key? key,
    }): super(key: key);
  @override
  LastStepState createState() => LastStepState();
}

class LastStepState extends State<LastStep> {
  bool loading = false;
  final TextEditingController _controller8 = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String tripName = '';

  void tripNameChanged(String str){
    setState((){
      tripName = str;
    });
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _controller8.dispose();
    _focusNode.dispose();
  }

  void next(AuthModel user)async{
    if(_controller8.text == ''){
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.red, content: Text('请给你的旅程起一个名字吧！', textAlign: TextAlign.center)),
      );
      return;
    }
    setState(() {
      loading = true;
    });
    List names = [];
    debugPrint(_controller8.text);
    _focusNode.unfocus();
    
    widget.trip.detail.asMap().forEach((index, value) {
      value.dayList.asMap().forEach((key, item) {
        names.add(item.nameOfScence);
      });
    });
    String result = names.join(',');

    try{
      ReturnInfos infos = await TravelDao.getInfos(result);
      widget.trip.tripName = _controller8.text;
      widget.trip.city = infos.city;
      widget.trip.country = infos.country;
      widget.trip.tags = infos.tags;
      if(widget.trip.designer == ''){
        widget.trip.designer = user.name;
      }
      TravelModel response = await TravelDao.save(widget.trip.toJson());
      if(response.uid != ''){
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.blue, content: Text('保存成功！', textAlign: TextAlign.center)),
        );

      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.red, content: Text('网络出错，请稍后再试！', textAlign: TextAlign.center)),
        );
      }
      setState(() {
        loading = false;
      });
      _controller8.text = '';
      Navigator.pushReplacementNamed(context, '/');
      Provider.of<UserData>(context, listen: false).setIndex([0,0]);
    }catch(err){
      debugPrint(err.toString());
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    AuthModel user = Provider.of<UserData>(context, listen: false).auth;
    return Scaffold(
      appBar: AppBar(
        title: const Text('最后的最后'),
        centerTitle:true,
        actions: [
          TextButton(
            onPressed: () => next(user),
            child: const Text('保存', style: TextStyle(color: Colors.black)),
          )
        ]
      ),
      body: Stack(
        children: [
          Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
              child: SizedBox(
                height: 50,
                child: TextField(
                  onChanged: tripNameChanged,
                  focusNode: _focusNode,
                  controller: _controller8,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(
                    fillColor: Color(0x30cccccc),
                    filled: true,
                    contentPadding: EdgeInsets.fromLTRB(10, 0, 0, 0),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0x00FF0000)),
                      borderRadius: BorderRadius.all(Radius.circular(10))),
                    hintText: '请给你的旅程起一个名字吧：',
                    hintStyle: TextStyle(color: Colors.grey),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0x00000000)),
                      borderRadius: BorderRadius.all(Radius.circular(10))),
                  ),
                ),
              ),
            ),
          ]),
          loading == true
          ? Center(
              child: Container(
              padding:  const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min, // 重要：使Column只占用必要空间
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16), // 间距
                  Text("正在保存中...", style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          )
          :Container(),
        ],
      )
      
    );
  }
}