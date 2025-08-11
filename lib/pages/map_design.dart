import 'package:flutter/material.dart';
//import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:nextsticker2/model/travel_model.dart';
import 'package:provider/provider.dart';
import 'package:nextsticker2/store/store.dart';
import 'package:nextsticker2/dao/travel_dao.dart';
import 'package:flutter/foundation.dart';
import 'package:nextsticker2/pages/arrange.dart';
import 'package:nextsticker2/pages/laststep.dart';

class MapDesign extends StatefulWidget {
  final TravelModel tripData;
  final dynamic platform;
  final Function setTripData;
  const MapDesign({
    Key? key,
    required this.tripData,
    @required this.platform,
    required this.setTripData
    }): super(key: key);
  @override
  MapDesignState createState() => MapDesignState();
}

class MapDesignState extends State<MapDesign> {
  late List tripList;
  String input = '';
  int indexNum = 0;
  late TravelModel cloneData;
  late List index;
  final GlobalKey<ScaffoldState> _scaffoldKey2 = GlobalKey<ScaffoldState>();
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  Widget platformView(string) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return widget.tripData.domestic == 1
      ?AndroidView(
        viewType: "gaodeDesign",
        creationParams: {'pointsString': string},
        creationParamsCodec: const StandardMessageCodec(),
      )
      : AndroidView(
        viewType: "googleDesign",
        creationParams: {'pointsString': string},
        creationParamsCodec: const StandardMessageCodec(),
      );
    }else{
      // return UiKitView(
      //   viewType: "googleMap",
      //   onPlatformViewCreated:(viewId){
      //     //print('viewId:$viewId');
      //   },
      //   creationParams: "points",
      //   creationParamsCodec: StandardMessageCodec()
      // );
      return Container();
    }
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  void _inputChanged(String str){
    setState((){
      input = str;
    });
  }

  void _delete(point){
    TravelModel clone = Provider.of<UserData>(context, listen: false).cloneData;
    for(int i =0; i < clone.detail.length; i++){
      cloneData.detail[i].dayList.removeWhere((element) => element.nameOfScence == point.nameOfScence);
    }
    Provider.of<UserData>(context, listen: false).setCloneData(clone);
    if(cloneData.detail[0].dayList.isNotEmpty && cloneData.detail[0].dayList.isNotEmpty){
      widget.platform.invokeMethod('InjectOnePoint', cloneData.detail[0].dayList[0].toJson().toString());
    } else {
      widget.platform.invokeMethod('clearPOI');
    }
  }

  void _onSubmit(str)async {
    await widget.platform.invokeMethod('findPOI', str);
    _controller.text = '';
    if (!context.mounted) return;
    Provider.of<UserData>(context, listen: false).setLoading(true);
  }

  void _reset(){
    Provider.of<UserData>(context, listen: false).setCloneData(widget.tripData.copy());
    //widget.platform.invokeMethod('InjectOnePoint',widget.tripData.copy().detail[index[0]].dayList[index[1]].toJson().toString());
    fedback('已恢复初始数据！');
  }

  void fedback(str){
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.blue, content: Text(str , textAlign: TextAlign.center)),
    );
  }

  void _addADay(){
    cloneData.detail.add(DayDetail(dayList: []));
    Provider.of<UserData>(context, listen: false).setCloneData(cloneData);
    fedback('已添加空白的一天');
  }

  void _deleteDay(index){
    if(cloneData.detail.length > 1){
      int dayLength = cloneData.detail.length - 2;
      cloneData.detail.removeAt(index);
      Provider.of<UserData>(context, listen: false).setCloneData(cloneData);
      Provider.of<UserData>(context, listen: false).setIndex([dayLength, 0]);
    } else {
      widget.platform.invokeMethod('clearPOI');
      Provider.of<UserData>(context, listen: false).setIndex([0, 0]);
    }
  }

  void _expand(index){
    List arrayIndex = [index, 0];
    debugPrint(arrayIndex.toString());
    Provider.of<UserData>(context, listen: false).setIndex(arrayIndex);
    setState(() {
      indexNum = indexNum == index ? -1 : index;
    });
  }

  void _save(cloneTrip) async{
    try{
      TravelModel response = await TravelDao.save(cloneTrip.toJson());
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
    }catch(err){
      debugPrint(err.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.red, content: Text('网络出错，请稍后再试！', textAlign: TextAlign.center)),
      );
    }
  }

  void _clearSearch(){
    Provider.of<UserData>(context, listen: false).setPoints([]);
    widget.platform.invokeMethod('clearPOI');
  }

  void _arrange(DetailModel point){
    debugPrint(point.nameOfScence);
  }

  void arrangeData(data){
    Provider.of<UserData>(context, listen: false).setCloneData(
      TravelModel(
        detail: data,
        uid: widget.tripData.uid,
        tripName: widget.tripData.tripName,
        designer: widget.tripData.designer,
        domestic: widget.tripData.domestic,
        city: widget.tripData.city,
        country: widget.tripData.country,
        tags: widget.tripData.tags,
        cover: widget.tripData.cover,
      )
    );
  }

  void jump(){
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => Arrange(
        tripData: Provider.of<UserData>(context, listen: false).cloneData,
        platform: widget.platform,
        width: MediaQuery.of(context).size.width,
        arrangeData: arrangeData,
        delete: _delete,
        from: 'mapDesign',
      )
    ));
  }

  void lastStep(){
    TravelModel cloneTrip = Provider.of<UserData>(context, listen: false).cloneData;
    TravelModel userData = Provider.of<UserData>(context, listen: false).userData;
    if(!checkDetail(cloneTrip.detail)){
      fedback('行程中有空白的天，请处理！');
      return;
    }
    if(cloneTrip.tripName != ''){
      _save(cloneTrip);
      if(cloneTrip.uid == userData.uid){
        widget.setTripData(cloneTrip, 5);
      } 
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => LastStep(
          platform: widget.platform,
          trip: cloneTrip,
          save: _save
          //designer: designer,
          //domestic: domestic,
          //uid: uid
        )
      ));
    }
  }

  Widget _sonItem(DetailModel point, context, platform, delete, arrange, arrayIndex){
    return
      InkWell(
        onTap: (){
          String pointString = point.toJson().toString();
          platform.invokeMethod('InjectOnePoint',pointString);
          Provider.of<UserData>(context, listen: false).setIndex(arrayIndex);
          index = arrayIndex;
          Navigator.pop(context);
        },
        onLongPress: () => arrange(point),
        child: ListTile(
          title: Text(point.nameOfScence),
          trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => delete(point)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    cloneData = Provider.of<UserData>(context, listen: false).cloneData;
    List points = Provider.of<UserData>(context).points;
    final List fixedList = Iterable<int>.generate(cloneData.detail.length).toList();
    List <ExpansionPanel>dataArray = [];
    fixedList.asMap().forEach((index, item){
      List <Widget>dayData = [];
      List dis1 = cloneData.detail[index].dayList;
      if(dis1.isEmpty){ 
    
      } else {
        dis1.asMap().forEach((indexInner, i){
          //if(i.category == 0){
            dayData.add(_sonItem(i, context, widget.platform, _delete, _arrange, [index, indexInner]));
          //}
        });
      }
      dataArray.add(
        ExpansionPanel(
          canTapOnHeader: true,
          isExpanded: indexNum == index,
          body: Column(
            children: dayData
          ),
          headerBuilder: (context, isExpanded) {
            return ListTile(
              title: Text('Day ${index + 1}'),
              onLongPress: () => _deleteDay(index),
              onTap: () => _expand(index),
            );
          },
        )
      );
    });
    //print('mapDesign:domestic:${cloneData.domestic}');
    return Scaffold(
      key: _scaffoldKey2,
      appBar: AppBar(
        title: TextButton(
          onLongPress: jump,
          onPressed: _reset,
          child: const Text('设计', style: TextStyle(color: Colors.black, fontSize: 20)),
        ),
        centerTitle:true,
        leading: IconButton(icon: const Icon(Icons.dehaze), onPressed: (){_scaffoldKey2.currentState?.openDrawer();}),
        actions: [
          TextButton(
            onPressed: _addADay,
            child: const Text('添加1日', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: lastStep,
            child: const Text('保存', style: TextStyle(color: Colors.black)),
          )
        ]
      ),
      drawer: Drawer(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('行程如下：'),
          ),
          body: SingleChildScrollView(
            child: 
              Column(
                children: [
                dataArray.isNotEmpty
                ?ExpansionPanelList(
                  elevation: 0,
                  dividerColor: Colors.white,
                  expandedHeaderPadding: const EdgeInsets.all(0),
                  expansionCallback: (index, isExpanded) {
                    if(index != indexNum){
                      setState(() {
                        indexNum = index;
                      });
                    } else {
                      setState(() {
                        indexNum = -1;
                      });
                    }
                  },
                  children: dataArray,
                )
                :const ListTile(title: Text('Day 1'))
              ],
            ),
          )
        )    
      ),   
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child:SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: platformView(cloneData.detail[0].dayList.isNotEmpty && cloneData.detail[0].dayList.isNotEmpty ? cloneData.detail[0].dayList[0].toJson().toString() : '')
            ),
          ),
          Positioned(
            right:5,
            left: 5,
            top: 5,
            child: SizedBox(
              height: 50,
              child: TextField(
                //autofocus: true,
                onSubmitted: _onSubmit,
                onChanged: _inputChanged,
                controller: _controller,
                decoration: InputDecoration(
                  suffixIcon: points.isNotEmpty 
                  ?GestureDetector(onTap: _clearSearch,child: const Icon(Icons.close),)
                  : null,
                  fillColor: Colors.white,
                  filled: true,
                  contentPadding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0x00FF0000)),
                    //borderRadius: BorderRadius.all(Radius.circular(50))
                  ),
                  hintText: '搜索关键字:',
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0x00000000)),
                    //borderRadius: BorderRadius.all(Radius.circular(50))
                  ),
                ),
              ),
            )
          ),
          points.isNotEmpty
          ?Positioned(
            right: 5,
            left: 5,
            top: 50,
            child: Wrap(children: chips(points as List<DetailModel>, widget.platform, true)),
          )
          :Container(),
          Provider.of<UserData>(context, listen: false).loading == true
          ?const Center(
            child: CircularProgressIndicator(),
          )
          :Container()
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          //Navigator.pushReplacementNamed(context, '/');
          _showMyDialog(context);
        },
        child: const Icon(Icons.arrow_back),
      ),
    );
  }
}

  Future<void> _showMyDialog(context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('即将返回首页地图!'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('未保存数据将丢失!'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('确定返回地图页'),
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/');
                Provider.of<UserData>(context, listen: false).setIndex([0,0]);
                Provider.of<UserData>(context, listen: false).setTrafficInfo([]);
                Provider.of<UserData>(context, listen: false).setPoints([]);
              },
            )
          ],
        );
      },
    );
  }

List<Widget> chips(List<DetailModel> points, platform, flag){
  List<Widget> a = [];
  points.asMap().forEach((index, item){
    a.add(GestureDetector(
      child: Visibility(
        visible: flag,
        child: Container(
          margin: const EdgeInsets.fromLTRB(0, 0, 5, 0),
          child: Chip(label: Text(item.nameOfScence, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.blue),
        ),
      ),
      onTap: () {
        String pointString = item.toJson().toString();
        platform.invokeMethod('InjectOnePoint',pointString);
        
      },
    )
    );
  });
  return a;
}

bool checkDetail(List array){
  for(int i =0 ; i < array.length ; i++){
    if(array[i].dayList.length == 0){
      return false;
    }
  }
  return true;
}

