import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nextsticker2/store/store.dart';

class Chat extends StatefulWidget {
  const Chat({
    Key? key,
  }): super(key: key);
  
  @override
  ChatState createState() => ChatState();
}
class ChatState extends State<Chat> {
  final TextEditingController _controller = TextEditingController();
  ScrollController controller1 = ScrollController();
  String content = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  void toBottom(){
    controller1.animateTo(controller1.position.maxScrollExtent + 150,
      duration: const Duration(milliseconds: 200),
      curve: Curves.ease
    );
  }

  bool validate(input){
    return input?.isNotEmpty ?? false;
  }

  void _onChanged(String str){
    setState((){
      content = str;
    });
  }

  void _send(socket, auth){
    socket.emit('chat message', {
      "user": auth,
      "inputContent": content
    });
    toBottom();
    setState((){
      _controller.text = '';
      content = '';
    });
  }

  Widget item(obj, auth){
    return
      Row(
        mainAxisAlignment: obj['user'] == auth ? MainAxisAlignment.end:MainAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: obj['user'] == auth ?Colors.blue : Colors.pinkAccent,
              borderRadius:BorderRadius.circular(10),
            ),
            height: 45,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.fromLTRB(0, 0, 0, 10),
            child: Text(obj["inputContent"], style: const TextStyle(fontSize: 20, color: Colors.white),),
          )
        ],
      );
  }

  void back(func){
    if(func != null){
      Navigator.of(context).pop();
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final dynamic data = ModalRoute.of(context)?.settings.arguments;
    final auth = Provider.of<UserData>(context, listen: false).auth;
    final socket = data["socket"];
    final func = data["openSnackBar"];
    List array = Provider.of<UserData>(context).chatArray;
    int num = Provider.of<UserData>(context).numInChatroom;
    return Scaffold(
      appBar: AppBar(
        title: const Text('即时聊天室'),
        centerTitle:true,
        leading: GestureDetector(child: const Icon(Icons.arrow_back_ios),onTap: () => back(func)),
        actions:<Widget>[
          num > 0
          ?TextButton(
            child: Text('$num 人在线', style: const TextStyle(color: Colors.white)),
            onPressed: () => {}
          )
          :Container()
        ]
      ),
      body: Stack(
        fit:StackFit.expand,
        children: [
          ListView.builder(
            scrollDirection: Axis.vertical,
            padding: EdgeInsets.fromLTRB(10, 10, 10, MediaQuery.of(context).padding.bottom + 60),
            reverse: false,
            shrinkWrap: true,
            itemCount: array.length,     
            cacheExtent: 30.0,
            controller: controller1,
            physics: const ClampingScrollPhysics(),
            itemBuilder: (context, i) {
              return item(array[i], auth);
            }
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              width: MediaQuery.of(context).size.width,
              padding: EdgeInsets.fromLTRB(10, 5, 5, MediaQuery.of(context).padding.bottom + 5),
              decoration: const BoxDecoration(
                //color: Colors.blue
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextField(  
                      //autofocus: true, 
                      onChanged: _onChanged,
                      controller: _controller,
                      decoration: const InputDecoration(
                        fillColor: Color.fromARGB(238, 204, 204, 204),
                        filled: true,
                        contentPadding: EdgeInsets.fromLTRB(10, 0, 0, 0),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0x00FF0000)),
                          borderRadius: BorderRadius.all(Radius.circular(10))),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0x00000000)),
                          borderRadius: BorderRadius.all(Radius.circular(10))),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap:content.trim() != '' ? () =>_send(socket, auth) : (){},
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                      child: const Icon(Icons.send, color: Colors.blue),
                    ),
                  )
                ],
              ),
            ),
          )
        ]
      ),
    );
  }
}