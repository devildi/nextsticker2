import 'package:flutter/material.dart';
import 'package:reorderables/reorderables.dart';
import 'package:nextsticker2/model/travel_model.dart';
import 'package:nextsticker2/pages/laststep.dart';

class Arrange extends StatefulWidget {
  final dynamic platform;
  final double width;
  final TravelModel tripData;
  final Function arrangeData;
  final Function delete;
  final String from;

  const Arrange({
    Key? key,
    required this.width,
    required this.platform,
    required this.tripData,
    required this.arrangeData,
    required this.delete,
    required this.from,
  }) : super(key: key);

  @override
  ArrangeState createState() => ArrangeState();
}

class ArrangeState extends State<Arrange> {
  List<DetailModel> data3 = [];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    List<List<DetailModel>> data6 = [];

    for (int i = 0; i < widget.tripData.detail.length; i++) {
      List<DetailModel> day = [];
      for (int j = 0; j < widget.tripData.detail[i].dayList.length; j++) {
        day.add(widget.tripData.detail[i].dayList[j]);
      }
      day.insert(0, DetailModel(nameOfScence: '第${i + 1}天'));
      data6.add(day);
    }

    data3 = data6.expand((e) => e).toList();
  }

  /// 删除逻辑（根据索引处理）
  void _deleteAt(int index) {
    final deletedItem = data3[index];
    setState(() {
      data3.removeAt(index);

      if (widget.from == 'mapDesign') {
        widget.delete(deletedItem);
      }

      // 判断是否需要移除前一个“第X天”标签（如果它是孤立的）
      if (index > 0 && data3[index - 1].nameOfScence.startsWith('第')) {
        if (index >= data3.length || data3[index].nameOfScence.startsWith('第')) {
          data3.removeAt(index - 1);
        }
      }
    });
  }

  /// 构建 widget 列表（根据 data3 动态生成）
  List<Widget> _buildWidgets() {
    return List.generate(data3.length, (index) {
      final item = data3[index];
      if (item.nameOfScence.startsWith('第') && item.nameOfScence.endsWith('天')) {
        return Container(
          width: widget.width,
          height: 40,
          color: Colors.blue,
          child: Center(
            child: Text(item.nameOfScence, style: const TextStyle(color: Colors.white)),
          ),
        );
      } else {
        return InputChip(
          avatar: CircleAvatar(
            backgroundImage: NetworkImage(item.picURL),
          ),
          label: Text(item.nameOfScence),
          deleteIcon: Container(
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(2),
            child: const Icon(Icons.close, size: 16, color: Colors.white),
          ),
          onDeleted: () => _deleteAt(index),
        );
      }
    });
  }

  /// 拖动排序
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final item = data3.removeAt(oldIndex);
      data3.insert(newIndex, item);
    });
  }

  /// 根据名称查找原始模型
  DetailModel? _findOriginalModel(String name) {
    for (var day in widget.tripData.detail) {
      for (var point in day.dayList) {
        if (point.nameOfScence == name) return point;
      }
    }
    return null;
  }

  void _saveArrange() {
    List<DayDetail> grouped = [];
    DayDetail currentDay = DayDetail(dayList: []);

    for (var item in data3) {
      if (item.nameOfScence.startsWith("第")) {
        currentDay = DayDetail(dayList: []);
        grouped.add(currentDay);
        print(grouped);
        // if (currentDay.dayList.isNotEmpty) {
        //   grouped.add(currentDay);
        //   currentDay = DayDetail(dayList: []);
        // }
      } else {
        final original = _findOriginalModel(item.nameOfScence);
        if (original != null) {
          currentDay.dayList.add(original);
        }
      }
    }
    //if (currentDay.dayList.isNotEmpty) grouped.add(currentDay);

    if (widget.from == 'list') {
      final hasEmptyDay = grouped.any((day) => day.dayList.isEmpty);
      if (hasEmptyDay) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("提示"),
            content: const Text("存在空的行程天，请检查并删除空天或添加景点。"),
            actions: [
              TextButton(
                child: const Text("确定"),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
        return; // ❗️不要继续执行跳转或保存
      }
      widget.tripData.detail = grouped;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LastStep(
            platform: widget.platform,
            trip: widget.tripData,
            save: () {},
          ),
        ),
      );
    } else {
      widget.arrangeData(grouped);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('景点排序'),
        centerTitle: true,
        leading: GestureDetector(
          child: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onTap: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _saveArrange,
            child: Text(
              widget.from == 'list' ? '下一步' : '保存',
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: ReorderableWrap(
          spacing: 8.0,
          runSpacing: 4.0,
          padding: const EdgeInsets.all(8),
          onReorder: _onReorder,
          onNoReorder: (index) {
            debugPrint('Reorder cancelled. index:$index');
          },
          onReorderStarted: (index) {
            debugPrint('Reorder started: index:$index');
          },
          children: _buildWidgets(),
        ),
      ),
    );
  }
}
