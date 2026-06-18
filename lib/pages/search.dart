import 'package:flutter/material.dart';
import 'package:nextsticker2/dao/travel_dao.dart';
import 'package:nextsticker2/model/travel_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';

class Search extends StatefulWidget {
  const Search({
    Key? key,
  }): super(key: key);
  @override
  SearchState createState() => SearchState();
}

class SearchState extends State<Search>{
  final TextEditingController _controller = TextEditingController();
  List tripList = [];
  bool isLoading = false;
  bool hasLoaded = false;
  bool networkState = true;
  final Set<String> _failedImages = {};

  void _handleImageError(dynamic trip) async {
    final bool isCover = trip.cover != '';
    final String nameOfScence = (trip.detail.isNotEmpty && trip.detail[0].dayList.isNotEmpty)
        ? trip.detail[0].dayList[0].nameOfScence
        : '';
    final String queryKey = '${trip.uid}_${isCover ? "cover" : nameOfScence}';
    
    if (_failedImages.contains(queryKey)) return;
    _failedImages.add(queryKey);
    
    final String searchName = isCover ? (trip.city != '' ? trip.city : nameOfScence) : nameOfScence;
    if (searchName.isEmpty) return;

    debugPrint('检测到图片链接失效，正在请求后台更新: $searchName');
    String newUrl = await TravelDao.handleImageFailure(
      uid: trip.uid,
      tripName: trip.tripName,
      nameOfScence: searchName,
      isCover: isCover,
    );
    
    if (newUrl.isNotEmpty) {
      debugPrint('后台图片已更新: $newUrl');
      if (mounted) {
        setState(() {
          if (isCover) {
            trip.cover = newUrl;
          } else {
            trip.detail[0].dayList[0].picURL = newUrl;
          }
        });
      }
    }
  }

  //String destination = '';

  @override
  void initState() {
    super.initState();
  }
  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  // void _onChanged(String str){
  //   setState((){
  //     destination = str;
  //   });
  // }

  void _back(){
    Navigator.of(context).pop();
  }

  void _onSubmitted(String string){
    //print(string);
    if(string.trim() != ''){
      setState(() {
        isLoading = true;
        getData(string);
      });
      _controller.text = '';
    }
  }

  Future <void> getData(string) async{
    try{
      AllTrip trips = await TravelDao.fetchAllByDescription(string);
      setState((){
        tripList = trips.allTripList;
        hasLoaded = true;
        isLoading = false;
      });
    }catch(err){
      setState((){
        isLoading = false;
        networkState = false;
      });
    }
  }
 
  @override
  Widget build(BuildContext context) {
    final dynamic data = ModalRoute.of(context)?.settings.arguments;
    List <Widget>gridData = [];
    if(tripList.isNotEmpty){
      tripList.asMap().forEach((index, element) {
        gridData.add(
          GestureDetector(
            onTap: (){Navigator.pushNamed(context, "detail", arguments: 
                {
                  "passData": element,
                  "userData": data["userData"],
                  "fn": data["fn"],
                  "index": 2
                }
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: (element.cover != '' || element.detail[0].dayList[0].picURL != '')
                          ? CachedNetworkImage(
                              imageUrl: element.cover != '' ? element.cover : element.detail[0].dayList[0].picURL,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) {
                                _handleImageError(element);
                                return Image.asset(
                                  "assets/trip_fallback.png",
                                  fit: BoxFit.cover,
                                );
                              },
                            )
                          : Image.asset(
                              "assets/trip_fallback.png",
                              fit: BoxFit.cover,
                            ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            element.tripName,
                            style: const TextStyle(color: Colors.white, fontSize: 20),
                          ),
                          Text(
                            element.city,
                            style: const TextStyle(color: Colors.white, fontSize: 20),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),
          );
      });
    }

    // ignore: non_constant_identifier_names
    Widget CostumGridView (offset){
      if(isLoading == true){
        return
          SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height - offset,
            child: const Center(child: CircularProgressIndicator()),
          );
      }
      if(hasLoaded == true){
        if(gridData.isNotEmpty){
          return 
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              crossAxisCount: 2,
              crossAxisSpacing: 10.0,
              mainAxisSpacing: 10.0,
              childAspectRatio: 1.0,
              children: gridData
            );
        }else {
          return
            SizedBox(
              height: MediaQuery.of(context).size.height - offset,
              child: const Center(child: Text('无结果！')),
            );
        }
      } 
      else{
        return SizedBox(
          height: MediaQuery.of(context).size.height - offset,
          child: Center(child: networkState == false ? const Text('网络错误！') : const Text('')),
        );
      } 
    }

    Widget result = Scaffold(
        body: ListView(
          padding: const EdgeInsets.only(bottom: 10),
          children: [
            const SizedBox(height: 5),
            SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(5, 0, 5, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _back,
                      child: const Icon(Icons.arrow_back_ios),
                    ),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        autofocus: true,
                        onSubmitted: _onSubmitted,
                        //onChanged: _onChanged,
                        controller: _controller,
                        decoration: const InputDecoration(
                          fillColor: Color(0x30cccccc),
                          filled: true,
                          contentPadding: EdgeInsets.fromLTRB(10, 0, 0, 0),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0x00FF0000)),
                            borderRadius: BorderRadius.all(Radius.circular(50))),
                          hintText: ' 要去哪里：',
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0x00000000)),
                            borderRadius: BorderRadius.all(Radius.circular(50))),
                        ),
                      ),
                    ) 
                  ],
                )
              ),
            ),
            CostumGridView(100)
          ],
        )
      );

      if(defaultTargetPlatform == TargetPlatform.android){
        return result;
      } else {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: result
        );
      }
  }
}