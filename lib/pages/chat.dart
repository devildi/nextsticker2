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
  final ScrollController _scrollController = ScrollController();
  String content = '';

  @override
  void initState() {
    super.initState();
    // Scroll to bottom after first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animated: false));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    if (_scrollController.hasClients) {
      if (animated) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    }
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
    setState((){
      _controller.text = '';
      content = '';
    });
    // Scroll to bottom after message is added to UI
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Widget item(obj, auth) {
    bool isMe = false;
    String senderName = '未知用户';
    String avatarUrl = '';

    if (obj['user'] != null) {
      if (obj['user'] is String) {
        senderName = obj['user'];
        isMe = (obj['user'] == auth.name || obj['user'] == auth.uid);
      } else if (obj['user'] is Map) {
        senderName = obj['user']['name'] ?? '未知用户';
        avatarUrl = obj['user']['avatar'] ?? '';
        isMe = (obj['user']['_id'] == auth.uid || obj['user']['name'] == auth.name);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.pink[50],
              backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl.isEmpty
                  ? Text(
                      senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.pinkAccent),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
                  child: Text(
                    senderName,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.65,
                ),
                decoration: BoxDecoration(
                  color: isMe ? Colors.blue : Colors.pinkAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(12),
                    topRight: const Radius.circular(12),
                    bottomLeft: Radius.circular(isMe ? 12 : 0),
                    bottomRight: Radius.circular(isMe ? 0 : 12),
                  ),
                  border: isMe ? null : Border.all(color: Colors.pinkAccent.withOpacity(0.2)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(
                  obj["inputContent"] ?? '',
                  style: TextStyle(
                    fontSize: 15,
                    color: isMe ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blue[100],
              backgroundImage: auth.avatar.isNotEmpty ? NetworkImage(auth.avatar) : null,
              child: auth.avatar.isEmpty
                  ? Text(
                      auth.name.isNotEmpty ? auth.name[0].toUpperCase() : '我',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
                    )
                  : null,
            ),
          ],
        ],
      ),
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
    final socket = data != null ? data["socket"] : null;
    final func = data != null ? data["openSnackBar"] : null;
    List array = Provider.of<UserData>(context).chatArray;
    int num = Provider.of<UserData>(context).numInChatroom;

    // Scroll to bottom when a new message arrives
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        title: const Text('即时聊天室'),
        centerTitle: true,
        leading: GestureDetector(
          child: const Icon(Icons.arrow_back_ios),
          onTap: () => back(func),
        ),
        actions: <Widget>[
          if (num > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$num 人在线',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.vertical,
              padding: const EdgeInsets.all(12.0),
              itemCount: array.length,
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              itemBuilder: (context, i) {
                return item(array[i], auth);
              },
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(10, 8, 8, MediaQuery.of(context).padding.bottom + 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: _onChanged,
                    controller: _controller,
                    style: const TextStyle(fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: '发送新消息...',
                      fillColor: Color.fromARGB(238, 240, 240, 240),
                      filled: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.transparent),
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.transparent),
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: content.trim().isNotEmpty ? () => _send(socket, auth) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Icon(
                      Icons.send,
                      color: content.trim().isNotEmpty ? Colors.blue : Colors.grey[400],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}