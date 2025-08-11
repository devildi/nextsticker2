import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class Input extends StatefulWidget {
  final Function sethasInput;
  final Function getData;
  const Input({
    Key? key,
    required this.sethasInput,
    required this.getData,
  }): super(key: key);
  @override
  InputState createState() => InputState();
}

class InputState extends State<Input> with SingleTickerProviderStateMixin{
  final TextEditingController _controller = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  late Animation<double> animation;
  late AnimationController controller;
  dynamic data;
  late Function getDataWithState;
  @override
  void initState(){
    super.initState();
    controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this
    );
    animation = Tween(begin: 180.0, end: 10.0).animate(controller)
      ..addListener(() {
        setState(()=>{});
      });
    controller.forward();
    const timeout = Duration(milliseconds: 200);
    Timer(timeout, () { 
      FocusScope.of(context).requestFocus(_commentFocus);
    });
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
    controller.dispose();
  }

  // void _onChanged(String str){
  //   setState((){
  //     destination = str;
  //   });
  // }

  void _back(){
    if(defaultTargetPlatform == TargetPlatform.android){
      Navigator.of(context).pop();
    }else if(defaultTargetPlatform == TargetPlatform.iOS){
      widget.sethasInput(false);
    }
    
  }
 
  @override
  Widget build(BuildContext context) {
    if(defaultTargetPlatform == TargetPlatform.android){
      data = ModalRoute.of(context)?.settings.arguments;
      getDataWithState = data["fn"];
    }
    void onSubmitted(String string){
      if(string.trim() != ''){
        if(defaultTargetPlatform == TargetPlatform.android){
          getDataWithState(string.trim());
          Navigator.of(context).pop();
        }else {
          widget.getData(string.trim());
          widget.sethasInput(false);        
        }
      }
    }

    Widget result = Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 5),
              Row(
                children: [
                  SizedBox(width: animation.value),
                  //SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      //autofocus: show,
                      focusNode: _commentFocus,
                      onSubmitted: onSubmitted,
                      //onChanged: _onChanged,
                      controller: _controller,
                      decoration: const InputDecoration(
                        fillColor: Color(0x30cccccc),
                        filled: true,
                        contentPadding: EdgeInsets.fromLTRB(10, 0, 0, 0),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0x00FF0000)),
                          borderRadius: BorderRadius.all(Radius.circular(50))),
                        hintText: ' 请输入行程编号：',
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0x00000000)),
                          borderRadius: BorderRadius.all(Radius.circular(50))),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _back,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                      child: const Text('取消'),
                    ),
                  )
                ],
              ),
            ]
          ),
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