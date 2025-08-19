import 'package:flutter/material.dart';
import 'dart:math';
import 'package:nextsticker2/pages/diy.dart';
import 'package:nextsticker2/tools/drag.dart';
import 'package:nextsticker2/tools/pop.dart';

class Tool extends StatefulWidget {
  final dynamic platform;
  const Tool({
    Key? key,
    @required this.platform,
    }): super(key: key);
  @override
  ToolState createState() => ToolState();
}

class ToolState extends State<Tool> {

  @override
  void initState() {
    super.initState();
    
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _item1(){
    return GestureDetector(
      child: ClipOval(
        child: Container(
          color: randomColor(),
          width: 65,
          height: 65,
          child: const Center(child: Text('DIY',style: TextStyle(fontSize: 15.0,color: Colors.black)))
        )
      ),
      onTap: (){
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => Diy(
            platform: widget.platform,
            setTripData: (){},
            getMore: (){}
          )
        ));
      }
    );
  }

  Widget _item2(){
    return GestureDetector(
      child: ClipOval(
        child: Container(
          color: randomColor(),
          width: 65,
          height: 65,
          child: const Center(child: Text('Pop',style: TextStyle(fontSize: 15.0,color: Colors.black)))
        )
      ),
      onTap: (){
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => const Pop(
            //platform: widget.platform
          )
        ));
      }
    );
  }

  Widget _item3(){
    return GestureDetector(
      child: ClipOval(
        child: Container(
          color: randomColor(),
          width: 65,
          height: 65,
          child: const Center(child: Text('Drag',style: TextStyle(fontSize: 15.0,color: Colors.black)))
        )
      ),
      onTap: (){
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => const Drag(
            //platform: widget.platform
          )
        ));
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('小工具集合'),
        centerTitle:true,
        leading: GestureDetector(
          child: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onTap: (){
            if(ModalRoute.of(context)?.settings.arguments !=null){
              Navigator.of(context).pop();
            }
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
        child: GridView.count(
          crossAxisCount: 5,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          padding: const EdgeInsets.all(5),
          childAspectRatio: 1,
          children: [_item1(),_item2(),_item3()],
        )
      ),
    );
  }
}

Color randomColor(){
  List colors = [Colors.red[100], Colors.green[100], Colors.yellow[100], Colors.orange[100]];
  Random random = Random();
  return colors[random.nextInt(4)];
}