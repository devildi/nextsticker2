import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewExample extends StatefulWidget {
  final String url;
  const WebViewExample({
    Key? key,
    required this.url
  }) : super(key: key);
  @override
  WebViewExampleState createState() => WebViewExampleState();
}

var list = ['引人不适', '内容质量较差', '过期内容', '标题党封面党'];

List<Widget> widgets = [];

class WebViewExampleState extends State<WebViewExample> {
  late WebViewController _controller;
  bool hasLoaded = false;

  @override
  void initState() {
    super.initState();
    // Initialize WebViewController with the new API
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (String url) {
          debugPrint('Page started loading: $url');
        },
        onPageFinished: (String url) {
          setState(() {
            hasLoaded = true;
          });
          debugPrint('Page finished loading: $url');
        },
        onNavigationRequest: (NavigationRequest request) {
          if (request.url.startsWith('https://www.youtube.com/')) {
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..addJavaScriptChannel(
        'Toaster',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('JS message: ${message.message}');
        },
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void fedback(str){
    debugPrint(str);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: Colors.blue, content: Text('感谢反馈！', textAlign: TextAlign.center)),
    );
  }

  Future<void> _show() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        String character = '引人不适';
        return AlertDialog(
          title: const Text('问题反馈：'),
          content: StatefulBuilder(builder: (context, StateSetter setState) {
            return SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  ListTile(
                    title: const Text('引人不适'),
                    leading: Radio(
                      value: '引人不适',
                      groupValue: character,
                      onChanged: (value){
                        setState(() {
                          character = value as String;
                        });
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('内容质量较差'),
                    leading: Radio(
                      value: '内容质量较差',
                      groupValue: character,
                      onChanged: (value){
                        setState(() {
                          character = value as String;
                        });
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('过期内容'),
                    leading: Radio(
                      value: '过期内容',
                      groupValue: character,
                      onChanged: (value){
                        setState(() {
                          character = value as String;
                        });
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('标题党封面党'),
                    leading: Radio(
                      value: '标题党封面党',
                      groupValue: character,
                      onChanged: (value){
                        setState(() {
                          character = value as String;
                        });
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
          actions: <Widget>[
            TextButton(
              child: const Text('提交反馈'),
              onPressed: () {
                Navigator.of(context).pop();
                fedback(character);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('故事'),
        centerTitle: true,
        actions: <Widget>[
          TextButton(
            onPressed: _show,
            child: const Text('内容反馈', style: TextStyle(color: Colors.white)),
          )
        ]
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          hasLoaded == false
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Container()
        ],
      ),
    );
  }
}