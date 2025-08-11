import 'package:flutter/material.dart';
//import 'package:reorderables/reorderables.dart';

class Drag extends StatefulWidget {
  //final platform;
  const Drag({
    Key? key,
    //@required this.platform,
    }): super(key: key);
  @override
  DragState createState() => DragState();
}

class DragState extends State<Drag> {
  List<ItemModel> items = [
    ItemModel("Item 1", false),
    ItemModel("Item 2", false),
    ItemModel("Item 3", false),
  ];
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Draggable Sorting in ExpansionPanel'),
      ),
      body: ReorderableListView(
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (oldIndex < newIndex) {
              newIndex -= 1;
            }
            final ItemModel item = items.removeAt(oldIndex);
            items.insert(newIndex, item);
          });
        },
        children: List.generate(
          items.length,
          (index) {
            final uniqueKey = Key(items[index].title);
            return ReorderableListItem(
              key: uniqueKey,
              index: index,
              item: items[index],
              callback: (bool isExpanded) {
                setState(() {
                  items[index].isExpanded = !isExpanded;
                });
              },
            );
          },
        ),
      ),
    );
  }
}

class ReorderableListItem extends StatelessWidget {
  
  final int index;
  final ItemModel item;
  final Function(bool isExpanded) callback;

  const ReorderableListItem({
    Key? key,
    required this.index,
    required this.item,
    required this.callback,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ExpansionPanelList(
      elevation: 1,
      expandedHeaderPadding: const EdgeInsets.all(0),
      expansionCallback: (int panelIndex, bool isExpanded) {
        callback(isExpanded);
      },
      children: [
        ExpansionPanel(
          //key: ValueKey(item.title),
          headerBuilder: (BuildContext context, bool isExpanded) {
            return ListTile(
              title: Text(item.title),
            );
          },
          body: ListTile(
            title: Text('Details for ${item.title}'),
          ),
          isExpanded: item.isExpanded,
        ),
      ],
    );
  }
}

class ItemModel {
  String title;
  bool isExpanded;

  ItemModel(this.title, this.isExpanded);
}
