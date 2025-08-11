import 'package:flutter/material.dart';

class ExpansionTileSample extends StatefulWidget {
  final List destinations;
  final Function openBottomSheet;
  final Function check;
  final int whichForDrawer;
  final Function setWhich;
 
  const ExpansionTileSample({
    Key? key, 
    required this.destinations, 
    required this.openBottomSheet,
    required this.check,
    required this.whichForDrawer,
    required this.setWhich
  }) : super(key: key);
  @override
  State<StatefulWidget> createState() => ExpansionTileSampleContentState();
}

class ExpansionTileSampleContentState extends State<ExpansionTileSample> {
  @override
  Widget build(BuildContext context) {
    //print(destinations[0].dayList[0].des+'~~~~');
    final List fixedList = Iterable<int>.generate(widget.destinations.length).toList();
    List <ExpansionPanel>dataArray = [];
    fixedList.asMap().forEach((index, item){
      List <Widget>dayData = [];
      List dis1 = widget.destinations[index].dayList;
      dis1.asMap().forEach((index1, i){
        if(i.category == 0){
          dayData.add(_sonItem(
            '${i.nameOfScence}', 
            context, 
            widget.openBottomSheet, 
            i.done,
            widget.check
          ));
        }
      });
      //dataArray.add(_item('Day ${index + 1}', dayData));
      dataArray.add(
        ExpansionPanel(
          canTapOnHeader: true,
          isExpanded: widget.whichForDrawer == index,
          body: Column(
            children: dayData
          ),
          headerBuilder: (context, isExpanded) {
            return ListTile(
              title: Text('Day ${index + 1}'),
            );
          },
        )
      );
    });
    // return ListView(
    //   children: dataArray
    // );
    
    return SingleChildScrollView(
      child: ExpansionPanelList(
        elevation: 0,
        dividerColor: Colors.white,
        expandedHeaderPadding: const EdgeInsets.all(0),
        expansionCallback: (index, isExpanded) {
          widget.setWhich(!isExpanded ? -1 : index);
        },
        children: dataArray,
      ),
    );
  }
}

Widget _sonItem(string, context, fn, done, check){
  return
    InkWell(
      onTap: (){
        Navigator.pop(context);
        fn(context, string);
      }, 
      onLongPress: (){
        Navigator.pop(context);
        debugPrint(string);
      },
      child: ListTile(
          title: Text(string,style: done 
            ? const TextStyle(
                decoration: TextDecoration.lineThrough
              )
            : null
          ),
          trailing: Checkbox(
            value: done,
            onChanged: (flag){
              check(string);
            },
          ),
        )
      );
}