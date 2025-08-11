import 'package:flutter/material.dart';

class MyFAB extends StatelessWidget {
  final dynamic platform;
  final bool isKeepingtrail;
  final Function stopTrail;
  const MyFAB({
    Key? key,
    required this.platform,
    required this.isKeepingtrail,
    required this.stopTrail
  }): super(key: key);
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: (){
        if(isKeepingtrail == true){
          debugPrint('取消鹰眼');
          stopTrail();
        }
      },
      child: FloatingActionButton(
        onPressed: (){
          platform.invokeMethod('startLoaction');
        },
        heroTag: 1,
        backgroundColor: isKeepingtrail == true ? Colors.indigo : Colors.blue,
        child: const Icon(Icons.location_searching, color: Colors.white,),
      )
    );
  }
}