import 'package:flutter/material.dart';
import 'package:nextsticker2/pages/inittrip2.dart';
// import 'package:nextsticker2/model/travel_model.dart';
// import 'package:nextsticker2/dao/travel_dao.dart';
// import 'package:provider/provider.dart';
// import 'package:nextsticker2/store/store.dart';

class InitTrip extends StatefulWidget {
  final dynamic platform;
  const InitTrip({
    @required this.platform,
    Key? key,
    }): super(key: key);
  @override
  InitTripState createState() => InitTripState();
}

class InitTripState extends State<InitTrip> {
  final TextEditingController _controller1 = TextEditingController();
  //final TextEditingController _controller2 = TextEditingController();
  final TextEditingController _controller3 = TextEditingController();
  //final TextEditingController _controller4 = TextEditingController();

  String tripName = '';
  //String designer = '';
  String domestic = '';
  //String uid = '555';

  void tripNameChanged(String str){
    setState((){
      tripName = str;
    });
  }

  // void designerChanged(String str){
  //   setState((){
  //     designer = str;
  //   });
  // }

  void domesticChanged(String str){
    setState((){
      domestic = str;
    });
  }

  // void uidChanged(String str){
  //   setState((){
  //     uid = str;
  //   });
  // }

  @override
  void initState() {
    super.initState();
  }

  void next()async{
    try{
      // TravelModel response = await TravelDao.fetch(uid);
      // if(response.uid != ''){
      //   if (!context.mounted) return;
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(backgroundColor: Colors.red, content: Text('行程编号已存在！', textAlign: TextAlign.center)),
      //   );
      // } else {
        if (!context.mounted) return;
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => InitTrip2(
            platform: widget.platform,
            tripName: tripName,
            //designer: designer,
            domestic: domestic,
            //uid: uid
          )
        ));
      //}
    }catch(err){
      debugPrint(err.toString());
    }
    
  }

  @override
  Widget build(BuildContext context) {
    //AuthModel user =  Provider.of<UserData>(context, listen: false).auth;
    return Scaffold(
      appBar: AppBar(
        title: const Text('完善信息'),
        centerTitle:true,
        actions: [
          //tripName != '' && designer != '' && uid != '' && domestic != ''
          TextButton(
            onPressed: next,
            child: const Text('下一步', style: TextStyle(color: Colors.black)),
          )
          // :TextButton(
          //   onPressed: (){},
          //   child: const Text('下一步', style: TextStyle(color: Colors.grey)),
          // )
        ]
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
          child: SizedBox(
            height: 50,
            child: TextField(
              onChanged: tripNameChanged,
              controller: _controller1,
              style: const TextStyle(color: Colors.black),
              decoration: const InputDecoration(
                fillColor: Color(0x30cccccc),
                filled: true,
                contentPadding: EdgeInsets.fromLTRB(10, 0, 0, 0),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0x00FF0000)),
                  borderRadius: BorderRadius.all(Radius.circular(10))),
                hintText: '行程名字',
                hintStyle: TextStyle(color: Colors.grey),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0x00000000)),
                  borderRadius: BorderRadius.all(Radius.circular(10))),
              ),
            ),
          ),
        ),
        // Padding(
        //   padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
        //   child: SizedBox(
        //     height: 50,
        //     child: TextField(
        //       onChanged: designerChanged,
        //       controller: _controller2,
        //       style: const TextStyle(color: Colors.black),
        //       decoration: const InputDecoration(
        //         fillColor: Color(0x30cccccc),
        //         filled: true,
        //         contentPadding: EdgeInsets.fromLTRB(10, 0, 0, 0),
        //         enabledBorder: OutlineInputBorder(
        //           borderSide: BorderSide(color: Color(0x00FF0000)),
        //           borderRadius: BorderRadius.all(Radius.circular(10))),
        //         hintText: '设计人',
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
              onChanged: domesticChanged,
              controller: _controller3,
              style: const TextStyle(color: Colors.black),
              decoration: const InputDecoration(
                fillColor: Color(0x30cccccc),
                filled: true,
                contentPadding: EdgeInsets.fromLTRB(10, 0, 0, 0),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0x00FF0000)),
                  borderRadius: BorderRadius.all(Radius.circular(10))),
                hintText: '国内还是国外（1/0）',
                hintStyle: TextStyle(color: Colors.grey),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0x00000000)),
                  borderRadius: BorderRadius.all(Radius.circular(10))),
              ),
            ),
          ),
        ),
        // Padding(
        //   padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
        //   child: SizedBox(
        //     height: 50,
        //     child: TextField(
        //       onChanged: uidChanged,
        //       controller: _controller4,
        //       style: const TextStyle(color: Colors.black),
        //       decoration: const InputDecoration(
        //         fillColor: Color(0x30cccccc),
        //         filled: true,
        //         contentPadding: EdgeInsets.fromLTRB(10, 0, 0, 0),
        //         enabledBorder: OutlineInputBorder(
        //           borderSide: BorderSide(color: Color(0x00FF0000)),
        //           borderRadius: BorderRadius.all(Radius.circular(10))),
        //         hintText: '行程编号',
        //         hintStyle: TextStyle(color: Colors.grey),
        //         focusedBorder: OutlineInputBorder(
        //           borderSide: BorderSide(color: Color(0x00000000)),
        //           borderRadius: BorderRadius.all(Radius.circular(10))),
        //       ),
        //     ),
        //   ),
        // )
      ],)
    );
  }
}