import 'package:flutter/material.dart';
import 'package:nextsticker2/widgets/expanmenu.dart';

class MyDrawer extends StatelessWidget {
  final List destinations;
  final Function openBottomSheet;
  final Function check;
  final int whichForDrawer;
  final Function setWhich;
  const MyDrawer({
    Key? key,
    required this.destinations, 
    required this.openBottomSheet,
    required this.check,
    required this.whichForDrawer,
    required this.setWhich
    }): super(key: key);
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('详细行程：'),
        ),
        body: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          child: ExpansionTileSample(
            destinations: destinations,
            openBottomSheet: openBottomSheet,
            check: check,
            whichForDrawer: whichForDrawer,
            setWhich: setWhich
          ),
        )
      )
    );
  }
}