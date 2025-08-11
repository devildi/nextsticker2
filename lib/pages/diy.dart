import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nextsticker2/pages/map_design.dart';
import 'package:provider/provider.dart';
import 'package:nextsticker2/store/store.dart';
import 'package:nextsticker2/model/travel_model.dart';

class Diy extends StatefulWidget {
  final dynamic platform;
  final Function setTripData;
  const Diy({
    Key? key,
    required this.platform,
    required this.setTripData,
    }): super(key: key);
  @override
  DiyState createState() => DiyState();
}

class DiyState extends State<Diy> {
  @override
  void initState() {
    super.initState();
  }

  void _jump(user){
    //行程初始化模版
    TravelModel trip = TravelModel(
      designer: user.name,
      detail: [DayDetail(dayList: [])],
      domestic: 1,
    );
    Provider.of<UserData>(context, listen: false).setCloneData(trip);
    //debugPrint(trip.toJson().toString());
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => MapDesign(
        platform: widget.platform,
        tripData: trip,
        setTripData: widget.setTripData,
      )
    ));
  }

  @override
  Widget build(BuildContext context) {
    AuthModel user = Provider.of<UserData>(context).auth;
    List trips = Provider.of<UserData>(context).trips;
    return Scaffold(
      appBar: AppBar(
        title: const Text('DIY'),
        centerTitle:true,
        actions: [
          TextButton(
            child: const Text('新建行程', style: TextStyle(color: Colors.black)),
            onPressed: () =>_jump(user)
              // Navigator.push(context, MaterialPageRoute(
              //   builder: (context) => InitTrip(
              //     platform: widget.platform,
              //   )
              // ));         
          )
        ]
      ),
      body: (trips.isNotEmpty
      ?ListView.builder(
        //controller: _controller,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: trips.length,
        itemBuilder: (BuildContext context, int index){
          return GestureDetector(
            onTap: (){
              Provider.of<UserData>(context, listen: false).setCloneData(trips[index].copy());
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => MapDesign(
                  platform: widget.platform,
                  tripData: trips[index],
                  setTripData: widget.setTripData,
                )
              ));
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(5, 5, 5, 0),
                child:Row(children: [
                  CachedNetworkImage(
                    imageUrl: trips[index]?.cover != '' ? trips[index]?.cover : trips[index].detail[0].dayList[0].picURL,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                  Container(width: 5),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('${trips[index].tripName}',overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20.0,color: Colors.black)),
                      Text('设计人:  ${trips[index].designer}',style: const TextStyle(fontSize: 15.0,color: Colors.black)),
                    ],
                  )
                ])
              )
          );
        },
      )
      :const Center(child: CircularProgressIndicator()))
    );
  }
}