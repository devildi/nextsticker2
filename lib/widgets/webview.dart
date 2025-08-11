import 'dart:async';
import 'dart:io';
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
  final Completer<WebViewController> _controller = Completer<WebViewController>();
  bool hasLoaded = false;
  
  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) WebView.platform = SurfaceAndroidWebView();
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
        centerTitle:true,
        actions: <Widget>[
          TextButton(
            onPressed: _show,
            child: const Text('内容反馈', style: TextStyle(color: Colors.white),),
          )
        ]
      ),
      // We're using a Builder here so we have a context that is below the Scaffold
      // to allow calling Scaffold.of(context) so we can show a snackbar.
      body: Builder(builder: (BuildContext context) {
        return Stack(
          children: [
            WebView(
              initialUrl: widget.url,
              javascriptMode: JavascriptMode.unrestricted,
              onWebViewCreated: (WebViewController webViewController) {
                _controller.complete(webViewController);
              },
              //javascriptChannels: <JavascriptChannel>[_toasterJavascriptChannel(context)].toSet(),
              javascriptChannels: {_toasterJavascriptChannel(context)},
              navigationDelegate: (NavigationRequest request) {
                if (request.url.startsWith('https://www.youtube.com/')) {
                  //print('blocking navigation to $request}');
                  return NavigationDecision.prevent;
                }
                //print('allowing navigation to $request');
                return NavigationDecision.navigate;
              },
              onPageStarted: (String url) {
                //print('Page started loading');
              },
              onPageFinished: (String url) {
                //print('Page finished loading');
                setState(() {
                  hasLoaded = true;      
                });
              },
              gestureNavigationEnabled: true,
            ),
            hasLoaded == false
            ?const Center(
              child: CircularProgressIndicator(),
            )
            :Container()
          ],
        );
      }),
    );
  }
}
JavascriptChannel _toasterJavascriptChannel(BuildContext context) {
  return JavascriptChannel(
    name: 'Toaster',
    onMessageReceived: (JavascriptMessage message) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message.message)),
      );
    });
}