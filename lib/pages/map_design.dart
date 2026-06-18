import 'dart:convert';
import 'dart:async';
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
import 'package:shared_preferences/shared_preferences.dart';

class MapDesign extends StatefulWidget {
  final TravelModel tripData;
  final dynamic platform;
  final Function setTripData;
  final Function onRefreshList;
  const MapDesign({
    Key? key,
    required this.tripData,
    @required this.platform,
    required this.setTripData,
    required this.onRefreshList
    }): super(key: key);
  @override
  MapDesignState createState() => MapDesignState();
}

class MapDesignState extends State<MapDesign> with WidgetsBindingObserver {
  late List tripList;
  String input = '';
  int indexNum = 0;
  late TravelModel cloneData;
  late List index;
  final GlobalKey<ScaffoldState> _scaffoldKey2 = GlobalKey<ScaffoldState>();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _hasDraft = false;
  String? _draftJson;
  bool _isBacking = false;
  bool _isGaodeMap = true;
  Timer? _expandTimer;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isGaodeMap = widget.tripData.domestic == 1;
    _checkDraft();
    _readClipboardToSearchBox();
  }

  Future<void> _readClipboardToSearchBox() async {
    try {
      ClipboardData? clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData != null && clipboardData.text != null && clipboardData.text!.isNotEmpty) {
        setState(() {
          _controller.text = clipboardData.text!;
          input = clipboardData.text!;
        });
      }
      if (_controller.text.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _searchFocusNode.requestFocus();
          }
        });
      }
    } catch (e) {
      debugPrint('获取剪切板数据失败: $e');
    }
  }

  Future<void> _checkDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draft = prefs.getString('map_design_draft');
    if (draft != null && draft.isNotEmpty) {
      setState(() {
        _hasDraft = true;
        _draftJson = draft;
      });
    }
  }

  Future<void> _restoreDraft() async {
    if (_draftJson == null) return;
    try {
      final decoded = json.decode(_draftJson!);
      final restoredTrip = TravelModel.fromJson(decoded);
      Provider.of<UserData>(context, listen: false).setCloneData(restoredTrip);
      setState(() {
        cloneData = restoredTrip;
        _hasDraft = false;
      });
      if (restoredTrip.detail.isNotEmpty && restoredTrip.detail[0].dayList.isNotEmpty) {
        widget.platform.invokeMethod('InjectOnePoint', restoredTrip.detail[0].dayList[0].toJson().toString());
      } else {
        widget.platform.invokeMethod('clearPOI');
      }
      fedback('已恢复上次的设计数据！');
    } catch (e) {
      debugPrint('恢复草稿错误: $e');
      fedback('恢复数据失败！');
    }
  }

  Future<void> _showSaveDraftDialog() async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('保存设计草稿'),
        content: const Text('您有正在设计的行程，是否保存为草稿？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('discard'),
            child: const Text('不保存', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('save'),
            child: const Text('保存', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );

    if (result == 'save') {
      setState(() {
        _isBacking = true;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('map_design_draft', json.encode(cloneData.toJson()));
      fedback('草稿已保存！');
      if (mounted) {
        Navigator.of(context).pop();
      }
    } else if (result == 'discard') {
      setState(() {
        _isBacking = true;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('map_design_draft');
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _showPasteLinkDialog() async {
    final TextEditingController linkController = TextEditingController();
    
    // Automatically read clipboard content if available
    try {
      ClipboardData? clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData != null && clipboardData.text != null && clipboardData.text!.isNotEmpty) {
        linkController.text = clipboardData.text!;
      }
    } catch (e) {
      debugPrint('获取剪切板数据失败: $e');
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('粘贴文本或链接'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: linkController,
              autofocus: true,
              maxLines: 6,
              minLines: 6,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    linkController.clear();
                  },
                  child: const Text('清空', style: TextStyle(color: Colors.red, fontSize: 16)),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () async {
                    final String url = linkController.text.trim();
                    if (url.isEmpty) return;
                    Navigator.of(context).pop(); // Close input dialog
                    
                    // Show loading indicator
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                    
                    try {
                      debugPrint('正在通过链接解析行程: $url');
                      final TravelModel parsedTrip = await TravelDao.fromLLM(url);
                      if (!mounted) return;
                      Navigator.of(context).pop(); // Close loading indicator
                      
                      if (parsedTrip.detail.isNotEmpty && parsedTrip.detail[0].dayList.isNotEmpty) {
                        Provider.of<UserData>(context, listen: false).setCloneData(parsedTrip);
                        setState(() {
                          cloneData = parsedTrip;
                        });
                        // Inject the first point to map
                        widget.platform.invokeMethod('InjectOnePoint', parsedTrip.detail[0].dayList[0].toJson().toString());
                        fedback('链接行程导入成功！');
                      } else {
                        fedback('解析失败，导入数据为空！');
                      }
                    } catch (e) {
                      if (mounted) {
                        Navigator.of(context).pop(); // Close loading indicator
                      }
                      debugPrint('解析链接失败: $e');
                      fedback('导入失败，请检查链接或稍后再试！');
                    }
                  },
                  child: const Text('解析', style: TextStyle(color: Colors.blue, fontSize: 16)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget platformView() {
    final firstPoint = (cloneData.detail.isNotEmpty && cloneData.detail[0].dayList.isNotEmpty)
        ? cloneData.detail[0].dayList[0].toJson().toString()
        : '';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _isGaodeMap
      ?AndroidView(
        key: const ValueKey('gaodeDesign'),
        viewType: "gaodeDesign",
        creationParams: {'pointsString': firstPoint},
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (_) => _onMapCreated(),
      )
      : AndroidView(
        key: const ValueKey('googleDesign'),
        viewType: "googleDesign",
        creationParams: {'pointsString': firstPoint},
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (_) => _onMapCreated(),
      );
    }else{
      return Container();
    }
  }

  void _onMapCreated() {
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _injectCurrentPoint();
    });
  }

  void _injectCurrentPoint() {
    final storeIndex = Provider.of<UserData>(context, listen: false).index;
    final data = Provider.of<UserData>(context, listen: false).cloneData;
    if (storeIndex.isNotEmpty &&
        storeIndex.length >= 2 &&
        data.detail.length > storeIndex[0] &&
        data.detail[storeIndex[0]].dayList.length > storeIndex[1]) {
      final point = data.detail[storeIndex[0]].dayList[storeIndex[1]];
      widget.platform.invokeMethod('InjectOnePoint', point.toJson().toString());
    } else if (data.detail.isNotEmpty && data.detail[0].dayList.isNotEmpty) {
      widget.platform.invokeMethod('InjectOnePoint', data.detail[0].dayList[0].toJson().toString());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchFocusNode.dispose();
    _expandTimer?.cancel();
    super.dispose();
    _controller.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _readClipboardToSearchBox();
    }
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
    if(widget.tripData.tripName != ''){
      Provider.of<UserData>(context, listen: false).setCloneData(widget.tripData.copy());
      //widget.platform.invokeMethod('InjectOnePoint',widget.tripData.copy().detail[index[0]].dayList[index[1]].toJson().toString());
      fedback('已恢复初始数据！');
    }
  }

  void _toggleMap() {
    setState(() {
      _isGaodeMap = !_isGaodeMap;
    });
  }

  void fedback(str){
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.blue, content: Text(str , textAlign: TextAlign.center)),
    );
  }

  void _addADay(){
    cloneData.detail.add(DayDetail(dayList: []));
    List arrayIndex = [cloneData.detail.length - 1, 0];
    Provider.of<UserData>(context, listen: false).setCloneData(cloneData);
    Provider.of<UserData>(context, listen: false).setIndex(arrayIndex);
    setState(() {
      indexNum = cloneData.detail.length - 1;
    });
    fedback('已添加空白的一天');
  }

  Future<void> _deleteDay(index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 Day ${index + 1} 的全部内容吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
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

  void _clearSearchBoxAndClipboard() async {
    _controller.clear();
    setState(() {
      input = '';
    });
    _clearSearch();
    try {
      await Clipboard.setData(const ClipboardData(text: ''));
      fedback('已清空搜索内容和剪贴板！');
    } catch (e) {
      debugPrint('清空剪切板失败: $e');
    }
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
        refreshList: widget.onRefreshList,
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
          save: _save,
          refresh: widget.onRefreshList,
          //designer: designer,
          //domestic: domestic,
          //uid: uid
        )
      ));
    }
  }

  Widget _sonItem(DetailModel point, int dayIndex, int pointIndex) {
    return SonItemWidget(
      point: point,
      dayIndex: dayIndex,
      pointIndex: pointIndex,
      onDelete: _delete,
      onMovePoint: _movePoint,
      platform: widget.platform,
      setIndex: (val) {
        Provider.of<UserData>(context, listen: false).setIndex(val);
        index = val;
      },
      onDragStarted: () {
        setState(() {
          _isDragging = true;
        });
      },
      onDragEnd: () {
        setState(() {
          _isDragging = false;
        });
      },
    );
  }

  void _movePoint({
    required int sourceDayIndex,
    required int sourcePointIndex,
    required int targetDayIndex,
    required int targetPointIndex,
  }) {
    setState(() {
      final DetailModel point = cloneData.detail[sourceDayIndex].dayList.removeAt(sourcePointIndex);
      
      int adjustedTargetIndex = targetPointIndex;
      if (sourceDayIndex == targetDayIndex && sourcePointIndex < targetPointIndex) {
        adjustedTargetIndex -= 1;
      }
      
      if (adjustedTargetIndex > cloneData.detail[targetDayIndex].dayList.length) {
        adjustedTargetIndex = cloneData.detail[targetDayIndex].dayList.length;
      }
      if (adjustedTargetIndex < 0) {
        adjustedTargetIndex = 0;
      }
      
      cloneData.detail[targetDayIndex].dayList.insert(adjustedTargetIndex, point);
      
      Provider.of<UserData>(context, listen: false).setCloneData(cloneData);
      
      if (cloneData.detail[targetDayIndex].dayList.isNotEmpty) {
        widget.platform.invokeMethod('InjectOnePoint', cloneData.detail[targetDayIndex].dayList[0].toJson().toString());
      }
    });
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
      dis1.asMap().forEach((indexInner, i){
        dayData.add(_sonItem(i, index, indexInner));
      });
      dataArray.add(
        ExpansionPanel(
          canTapOnHeader: true,
          isExpanded: indexNum == index,
          body: DragTarget<DragPointData>(
            onWillAcceptWithDetails: (details) => true,
            onAcceptWithDetails: (details) {
              final source = details.data;
              _movePoint(
                sourceDayIndex: source.dayIndex,
                sourcePointIndex: source.pointIndex,
                targetDayIndex: index,
                targetPointIndex: dis1.length,
              );
            },
            builder: (context, candidateData, rejectedData) {
              final isHovering = candidateData.isNotEmpty;
              return Container(
                color: isHovering ? Colors.blue.withOpacity(0.05) : Colors.transparent,
                child: Column(
                  children: [
                    if (dis1.isEmpty)
                      Container(
                        height: 60,
                        alignment: Alignment.center,
                        child: Text(
                          '暂无行程点，拖拽至此添加',
                          style: TextStyle(color: Colors.grey[400], fontSize: 13),
                        ),
                      )
                    else ...[
                      ...dayData,
                      if (_isDragging)
                        DragTarget<DragPointData>(
                          onWillAcceptWithDetails: (details) => details.data.dayIndex != index || details.data.pointIndex != dis1.length - 1,
                          onAcceptWithDetails: (details) {
                            final source = details.data;
                            _movePoint(
                              sourceDayIndex: source.dayIndex,
                              sourcePointIndex: source.pointIndex,
                              targetDayIndex: index,
                              targetPointIndex: dis1.length,
                            );
                          },
                          builder: (context, candidateData, rejectedData) {
                            final isHovered = candidateData.isNotEmpty;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              height: 40,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: isHovered ? Colors.blue.withOpacity(0.1) : Colors.black.withOpacity(0.02),
                                border: Border.all(
                                  color: isHovered ? Colors.blue : Colors.grey[300]!,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: Text(
                                  isHovered ? '松手移至末尾' : '拖拽至此移至末尾',
                                  style: TextStyle(
                                    color: isHovered ? Colors.blue : Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
          headerBuilder: (context, isExpanded) {
            return DragTarget<DragPointData>(
              onWillAcceptWithDetails: (details) {
                if (indexNum != index) {
                  _expandTimer?.cancel();
                  _expandTimer = Timer(const Duration(milliseconds: 300), () {
                    if (mounted) {
                      setState(() {
                        indexNum = index;
                      });
                    }
                  });
                }
                return true;
              },
              onLeave: (data) {
                _expandTimer?.cancel();
              },
              onAcceptWithDetails: (details) {
                final source = details.data;
                _movePoint(
                  sourceDayIndex: source.dayIndex,
                  sourcePointIndex: source.pointIndex,
                  targetDayIndex: index,
                  targetPointIndex: 0,
                );
              },
              builder: (context, candidateData, rejectedData) {
                return ListTile(
                  title: Text('Day ${index + 1}'),
                  onLongPress: () => _deleteDay(index),
                  onTap: () => _expand(index),
                );
              },
            );
          },
        )
      );
    });
    //print('mapDesign:domestic:${cloneData.domestic}');
    return PopScope(
      canPop: _isBacking,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final hasData = cloneData.detail.any((day) => day.dayList.isNotEmpty);
        if (!hasData) {
          setState(() { _isBacking = true; });
          if (mounted) Navigator.of(context).pop();
          return;
        }
        await _showSaveDraftDialog();
      },
      child: Scaffold(
        key: _scaffoldKey2,
        appBar: AppBar(
          title: FittedBox(
            fit: BoxFit.scaleDown,
            child: TextButton(
              onLongPress: jump,
              onPressed: _reset,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('设计', style: TextStyle(color: Colors.black, fontSize: 20)),
            ),
          ),
          centerTitle: true,
          leadingWidth: 120,
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 8),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.dehaze, color: Colors.black),
                onPressed: () => _scaffoldKey2.currentState?.openDrawer(),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: _showPasteLinkDialog,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '粘贴',
                  style: TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
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
                child: platformView(),
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
                  focusNode: _searchFocusNode,
                  onSubmitted: _onSubmit,
                  onChanged: _inputChanged,
                  controller: _controller,
                  decoration: InputDecoration(
                    suffixIcon: input.isNotEmpty 
                    ?GestureDetector(onTap: _clearSearchBoxAndClipboard,child: const Icon(Icons.close),)
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
            Positioned(
              left: 16,
              bottom: 16,
              child: FloatingActionButton(
                heroTag: 'map_toggle_fab',
                onPressed: _toggleMap,
                backgroundColor: Colors.white,
                child: ClipOval(
                  child: Image.asset(
                    _isGaodeMap ? "assets/google.png" : "assets/gaode.png",
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            Provider.of<UserData>(context, listen: false).loading == true
            ?const Center(
              child: CircularProgressIndicator(),
            )
            :Container()
          ],
        ),
        floatingActionButton: _hasDraft
            ? FloatingActionButton(
                heroTag: 'restore_draft_fab',
                onPressed: _restoreDraft,
                backgroundColor: Colors.white,
                child: const Icon(Icons.restore, color: Colors.blue),
              )
            : null,
      ),
    );
  }
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

class DragPointData {
  final int dayIndex;
  final int pointIndex;
  final DetailModel point;

  DragPointData({
    required this.dayIndex,
    required this.pointIndex,
    required this.point,
  });
}

class SonItemWidget extends StatefulWidget {
  final DetailModel point;
  final int dayIndex;
  final int pointIndex;
  final Function(DetailModel) onDelete;
  final Function({required int sourceDayIndex, required int sourcePointIndex, required int targetDayIndex, required int targetPointIndex}) onMovePoint;
  final dynamic platform;
  final Function(List) setIndex;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnd;

  const SonItemWidget({
    Key? key,
    required this.point,
    required this.dayIndex,
    required this.pointIndex,
    required this.onDelete,
    required this.onMovePoint,
    required this.platform,
    required this.setIndex,
    required this.onDragStarted,
    required this.onDragEnd,
  }) : super(key: key);

  @override
  _SonItemWidgetState createState() => _SonItemWidgetState();
}

class _SonItemWidgetState extends State<SonItemWidget> {
  bool _isHoveringTop = false;
  bool _isHoveringBottom = false;

  @override
  Widget build(BuildContext context) {
    final dragData = DragPointData(
      dayIndex: widget.dayIndex,
      pointIndex: widget.pointIndex,
      point: widget.point,
    );

    final isLoading = Provider.of<UserData>(context, listen: true).processingNames.contains(widget.point.nameOfScence);

    Widget itemWidget = ListTile(
      title: Text(widget.point.nameOfScence),
      trailing: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => widget.onDelete(widget.point),
            ),
    );

    return DragTarget<DragPointData>(
      onWillAcceptWithDetails: (details) {
        return details.data.point != widget.point;
      },
      onMove: (details) {
        final source = details.data;
        bool isTop;
        if (source.dayIndex == widget.dayIndex && source.pointIndex == widget.pointIndex - 1) {
          // Dragging the item directly above onto this item.
          // Place it below this item (swap).
          isTop = false;
        } else if (source.dayIndex == widget.dayIndex && source.pointIndex == widget.pointIndex + 1) {
          // Dragging the item directly below onto this item.
          // Place it above this item (swap).
          isTop = true;
        } else {
          final RenderBox renderBox = context.findRenderObject() as RenderBox;
          final localOffset = renderBox.globalToLocal(details.offset);
          isTop = localOffset.dy < (renderBox.size.height / 2);
        }
        setState(() {
          _isHoveringTop = isTop;
          _isHoveringBottom = !isTop;
        });
      },
      onLeave: (data) {
        setState(() {
          _isHoveringTop = false;
          _isHoveringBottom = false;
        });
      },
      onAcceptWithDetails: (details) {
        final source = details.data;
        bool isTop;
        if (source.dayIndex == widget.dayIndex && source.pointIndex == widget.pointIndex - 1) {
          isTop = false;
        } else if (source.dayIndex == widget.dayIndex && source.pointIndex == widget.pointIndex + 1) {
          isTop = true;
        } else {
          final RenderBox renderBox = context.findRenderObject() as RenderBox;
          final localOffset = renderBox.globalToLocal(details.offset);
          isTop = localOffset.dy < (renderBox.size.height / 2);
        }
        final targetIndex = isTop ? widget.pointIndex : widget.pointIndex + 1;

        setState(() {
          _isHoveringTop = false;
          _isHoveringBottom = false;
        });

        widget.onMovePoint(
          sourceDayIndex: source.dayIndex,
          sourcePointIndex: source.pointIndex,
          targetDayIndex: widget.dayIndex,
          targetPointIndex: targetIndex,
        );
      },
      builder: (context, candidateData, rejectedData) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top drop indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              height: _isHoveringTop ? 4 : 0,
              color: Colors.blue,
              margin: EdgeInsets.symmetric(vertical: _isHoveringTop ? 4 : 0),
            ),
            LongPressDraggable<DragPointData>(
              data: dragData,
              onDragStarted: widget.onDragStarted,
              onDragEnd: (_) => widget.onDragEnd(),
              onDraggableCanceled: (_, __) => widget.onDragEnd(),
              feedback: Material(
                elevation: 4.0,
                child: Container(
                  width: 250,
                  color: Colors.white,
                  child: ListTile(
                    title: Text(widget.point.nameOfScence),
                    trailing: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => widget.onDelete(widget.point),
                          ),
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.4,
                child: itemWidget,
              ),
              child: ListTile(
                title: Text(widget.point.nameOfScence),
                onTap: () {
                  String pointString = widget.point.toJson().toString();
                  widget.platform.invokeMethod('InjectOnePoint', pointString);
                  widget.setIndex([widget.dayIndex, widget.pointIndex]);
                  Navigator.pop(context);
                },
                trailing: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => widget.onDelete(widget.point),
                      ),
              ),
            ),
            // Bottom drop indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              height: _isHoveringBottom ? 4 : 0,
              color: Colors.blue,
              margin: EdgeInsets.symmetric(vertical: _isHoveringBottom ? 4 : 0),
            ),
          ],
        );
      },
    );
  }
}

