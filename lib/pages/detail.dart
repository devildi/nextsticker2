import 'package:flutter/material.dart';
import 'package:nextsticker2/model/travel_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nextsticker2/dao/travel_dao.dart';

class Detail extends StatefulWidget {
  const Detail({
    Key? key,
  }): super(key: key);

  @override
  DetailState createState() => DetailState();
}

class DetailState extends State<Detail> {
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

  @override
  Widget build(BuildContext context) {
    final dynamic data = ModalRoute.of(context)?.settings.arguments;
    final Function fn = data["fn"];
    final TravelModel userData = data["userData"];
    final TravelModel passData = data["passData"];
    final int index = data["index"];
    final array = passData.detail;
    
    final String coverUrl = passData.cover != ''
        ? passData.cover
        : (array.isNotEmpty && array[0].dayList.isNotEmpty)
            ? array[0].dayList[0].picURL
            : '';

    void apply(){
      fn(passData, index);
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Text(
          passData.tripName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 4.0,
                color: Colors.black54,
              ),
            ],
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          if (hasData(userData, passData))
            Container(
              margin: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: apply,
                child: const Text(
                  '应用数据',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Premium Header Stack
            Stack(
              clipBehavior: Clip.none,
              children: [
                Hero(
                  tag: passData.uid,
                  child: Container(
                    height: 280,
                    width: double.infinity,
                    foregroundDecoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.4),
                          Colors.black.withOpacity(0.1),
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                    child: coverUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: coverUrl,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) {
                            _handleImageError(passData);
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
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 2. Timeline List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: array.length,
              itemBuilder: (context, i) {
                final dayData = array[i];
                final activeDayList = dayData.dayList.where((pt) => pt.category == 0).toList();
                
                return _buildTimelineRow(
                  context,
                  dayIndex: i,
                  isLast: i == array.length - 1,
                  dayList: activeDayList,
                  trip: passData,
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineRow(BuildContext context, {
    required int dayIndex,
    required bool isLast,
    required List<DetailModel> dayList,
    required dynamic trip,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (Day Indicator)
        SizedBox(
          width: 48,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.indigo[400]!,
                  Colors.indigo[800]!,
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.indigo.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'D${dayIndex + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Right Itinerary Card
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: dayList.isEmpty
              ? Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[200]!),
                  ),
                  color: Colors.white,
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      '今天没有规划景点行程哦~',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                )
              : Column(
                  children: dayList.asMap().entries.map((entry) {
                    final int sceneIdx = entry.key;
                    final DetailModel j = entry.value;
                    return _buildSceneCard(context, j, sceneIdx, trip);
                  }).toList(),
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildSceneCard(BuildContext context, DetailModel j, int index, dynamic trip) {
    final bool hasImage = j.picURL.isNotEmpty;
    
    return Container(
      margin: EdgeInsets.only(top: index == 0 ? 0 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left colorful tag decoration
              Container(
                width: 4,
                color: Colors.indigo[300]!.withOpacity(0.7),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Scene name and description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 14, color: Colors.indigo),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    j.nameOfScence,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (j.des.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                j.des,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Optional attraction thumbnail
                      if (hasImage) ...[
                        const SizedBox(width: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 64,
                              height: 64,
                              child: CachedNetworkImage(
                                imageUrl: j.picURL,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[100],
                                  child: const Center(
                                    child: SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) {
                                  // Call image failure handler if the image loading fails
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    _handleImageError(trip);
                                  });
                                  return Image.asset(
                                    "assets/trip_fallback.png",
                                    fit: BoxFit.cover,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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