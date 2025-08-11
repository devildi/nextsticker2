import 'package:flutter/material.dart';

class MyBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final Function onItemTapped;
  void _onItemTapped(int index){
    onItemTapped(index);
  }
  const MyBottomNavigationBar({
    Key? key,
    required this.selectedIndex, 
    required this.onItemTapped
    }): super(key: key);
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      items: <BottomNavigationBarItem>[
        selectedIndex == 0 ? const BottomNavigationBarItem(icon: Icon(Icons.location_searching), label: '定位') : const BottomNavigationBarItem(icon: Icon(Icons.map), label: '地图'),
        const BottomNavigationBarItem(icon: Icon(Icons.list), label: '行程'),
        const BottomNavigationBarItem(icon: Icon(Icons.school), label: '故事'),
        const BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
      ],
      currentIndex: selectedIndex,
      type: BottomNavigationBarType.fixed,
      fixedColor: Colors.blue,
      onTap: _onItemTapped,
      elevation: 0,
    );
  }
}