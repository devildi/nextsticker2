import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nextsticker2/tools/tools.dart';
import 'dart:io';
import 'package:dio/dio.dart';

class ImageWithFallback extends StatefulWidget {
  final String remoteURL;
  final String resourceId;
  final double width;
  final double picWidth;
  final double picHeight;
  final String name;

  const ImageWithFallback({
    Key? key,
    required this.remoteURL,
    required this.resourceId,
    required this.name,
    required this.width,
    required this.picWidth,
    required this.picHeight,
  }) : super(key: key);

  @override
  State<ImageWithFallback> createState() => ImageWithFallbackState();
}

class ImageWithFallbackState extends State<ImageWithFallback> {
  String localFileURL = '';
  @override
  void initState() {
    super.initState();
    _checkFile(widget.remoteURL, widget.resourceId, widget.name);
  }

  Future<void> _checkFile(remoteURL, resourceId, name) async {
    bool isExists = await CommonUtils.isFileExist(resourceId);
    String localFileURL111 = '';
    if (!isExists) {
      _downloadImage(remoteURL, await CommonUtils.getLocalURLForResource(resourceId));
      debugPrint('$name的图片不存在，开始下载...');
    } else{
      localFileURL111 = await CommonUtils.getLocalURLForResource(resourceId);     
      debugPrint('$name使用本地图片');
    }
    if (mounted) {
      setState(() {
        localFileURL = localFileURL111;
      });
    }
  }

  Future<void> _downloadImage(String url, String path) async {
    try {
      final response = await Dio().get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final file = File(path);
      await file.create(recursive: true);
      await file.writeAsBytes(response.data!);
      if (mounted) {
        setState(() {
           localFileURL = file.path;
        });
      }
    } catch (e) {
      debugPrint('图片下载失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final double height = widget.width * widget.picHeight / widget.picWidth;
    return Container(
      decoration: const BoxDecoration(color: Colors.transparent),
      width: widget.width,
      height: height,
      child: localFileURL != ''
      ? Image.file(
          File(localFileURL),
          fit: BoxFit.cover,
        )
      : CachedNetworkImage(
          imageUrl: widget.remoteURL,
          fit: BoxFit.cover,
        ),
    );
  }
}