import 'package:flutter/material.dart';
import 'package:nextsticker2/model/travel_model.dart';
import 'package:cached_network_image/cached_network_image.dart';

class Detail extends StatelessWidget {
  const Detail({
    Key? key,
  }): super(key: key);
  @override
  Widget build(BuildContext context) {
    final dynamic data = ModalRoute.of(context)?.settings.arguments;
    final Function fn = data["fn"];
    final TravelModel userData = data["userData"];
    final TravelModel passData = data["passData"];
    final int index = data["index"];
    final array = passData.detail;
    //print(array[0].dayList[0].picURL);
    final List fixedList = Iterable<int>.generate(array.length).toList();
    List <Widget>dataArray = [];
    dataArray.add(photo(context, passData.cover != '' ? passData.cover : array[0].dayList[0].picURL, passData));
    fixedList.asMap().forEach((i, item){
      List <Widget>sunArray = [];
      array[i].dayList.asMap().forEach((index1, j){
        if(j.category == 0){
          sunArray.add(sunItem(j));
        }
      });
      dataArray.add(_item(i, sunArray));
    });

    void apply(){
      fn(passData, index);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(passData.tripName),
        centerTitle:true,
        actions: <Widget>[
          hasData(userData, passData)
          ? TextButton(onPressed: apply, child: const Text('应用数据', style:TextStyle(color: Colors.black)), )
          : GestureDetector(child: Image.asset("assets/chatgpt.png"), onTap: () => {debugPrint('chatgpt')})
        ],
      ),
      body: ListView(children: dataArray)
    );
  }
}

bool hasData(userData, passData){
  if(userData == null){
    return true;
  } 
  if(passData.uid != userData.uid){
    return true;
  } else {
    return false;
  }
}

Widget sunItem(i){
  return 
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('${i.nameOfScence}',style: const TextStyle(fontSize: 30.0)),
        Container(
          decoration: const BoxDecoration(
            // border: Border(
            //   left: BorderSide(
            //     width: 3,//宽度
            //     color: Colors.blueAccent, //边框颜色
            //   ),
            // ),
          ),
          child: Text('${i.des}',style: const TextStyle(fontSize: 15.0, color: Colors.grey)),
        )
      ],
    );
}

Widget photo(context, url, passData){
  return 
    Hero(
      tag: passData.uid,
      child: 
        CachedNetworkImage(
          imageUrl: url,
          width: MediaQuery.of(context).size.width,
          height: 250,
          fit: BoxFit.cover,
        )
    );
}

Widget _item (i,children) {
  return Padding(
    padding: const EdgeInsets.all(3.0),
    child: 
      Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipOval(
          child: Container(
            color: Colors.blue,
            width: 65,
            height: 65,
            child: Center(child: Text('Day ${i+1}',style: const TextStyle(fontSize: 20.0,color: Colors.white)))
          )
        ),
        Expanded(
          child: Card(
            elevation: 3,
            child: Container(
              margin: const EdgeInsets.fromLTRB(5, 0, 5, 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        )
      ],
    ));
}