import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DetailCard extends StatefulWidget {
  final dynamic trip;
  final String tripIndex;
  final double dialogWidth;
  final Function(int) updateCategory;
  final Function jump;
  final Function onDescriptionChanged;

  const DetailCard({
    Key? key,
    required this.trip,
    required this.tripIndex,
    required this.dialogWidth,
    required this.updateCategory,
    required this.jump,
    required this.onDescriptionChanged,
  }) : super(key: key);
    @override
  DetailCardState createState() => DetailCardState();
}

class DetailCardState extends State<DetailCard>{
  late final TextEditingController _descriptionController;
  List<int> getIndex(str){
    List<String> parts = str.split('-');
    List<int> numbers = parts.map((s) {
      return int.tryParse(s) ?? 0; // 转换失败时返回0
    }).toList();
    return numbers;
  }

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.trip.des); // 初始化
  }

  @override
  void dispose() {
    _descriptionController.dispose(); // 释放控制器
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {},
                    child: Text(
                      '${widget.trip.nameOfScence}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    )
                  ),
                  const SizedBox(width: 8)
                ],
              ),
              Text(
                '第${getIndex(widget.tripIndex)[0] + 1}天第${getIndex(widget.tripIndex)[1] + 1}个景点',
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: widget.trip.picURL,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                onChanged: (text) {
                  setState(() {
                    widget.trip.des = text;
                  });
                  widget.onDescriptionChanged(text);
                },
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '景点描述',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton(
                    onPressed: () => widget.updateCategory(0),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: widget.trip.category == 0 ? Colors.blue : Colors.transparent,
                      foregroundColor: widget.trip.category == 0 ? Colors.white : Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                    ),
                    child: const Text('景点'),
                  ),
                  OutlinedButton(
                    onPressed: () => widget.updateCategory(2),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: widget.trip.category == 2 ? Colors.blue : Colors.transparent,
                      foregroundColor: widget.trip.category == 2 ? Colors.white : Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                    ),
                    child: const Text('吃喝'),
                  ),
                  OutlinedButton(
                    onPressed: () => widget.updateCategory(1),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: widget.trip.category == 1 ? Colors.blue : Colors.transparent,
                      foregroundColor: widget.trip.category == 1 ? Colors.white : Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                    ),
                    child: const Text('住宿'),
                  )
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: (){
                        Navigator.of(context).pop();
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('返回'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => widget.jump(),
                      child: const Text('下一步'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}