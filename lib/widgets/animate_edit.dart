import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';

class MyAnimateEdit extends StatefulWidget {
  final bool isActive;
  final Function openSnackBar;
  final String auth;
  final dynamic platform;
  final dynamic socket;
  final Function initUserData;
  const MyAnimateEdit({
    required this.isActive,
    required this.openSnackBar,
    required this.auth,
    required this.platform,
    required this.socket,
    required this.initUserData,
    Key? key,
  }): super(key: key);

  @override
  MyAnimateEditState createState() => MyAnimateEditState();
}

class MyAnimateEditState extends State<MyAnimateEdit> with SingleTickerProviderStateMixin{
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  bool openBTN = false;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      value: openBTN ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.easeOutQuad,
      parent: _controller,
    );
  }

  @override
  void didUpdateWidget(MyAnimateEdit oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Automatically close the FAB when switching away from this tab (isActive changes from true to false)
    if (oldWidget.isActive && !widget.isActive) {
      if (openBTN) {
        close();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void jump(str){
    if(widget.auth != ''){
      switch(str) {
        case "editMicro":
          close();
          Navigator.pushNamed(context, "editMicro", arguments: {
            "openSnackBar": widget.openSnackBar,
            "uid": widget.auth,
            "initUserData": widget.initUserData
          });
          break;
        case "editMovie":
          close();
          Navigator.pushNamed(context, "editMovie", arguments: {
            "openSnackBar": widget.openSnackBar,
            "platform": widget.platform,
            "uid": widget.auth,
            "initUserData": widget.initUserData
          });
          break;
        case "chat":
          close();
          Navigator.pushNamed(context, "chat", arguments: {
            "socket": widget.socket
          });
          break;
        default:
      }
    } else {
      Navigator.pushNamed(context, "login", arguments: {
        "fn": widget.openSnackBar,
        "from": str,
        "platform": widget.platform,
        "socket": widget.socket,
        "initUserData": widget.initUserData
      });
      close();
    }
  }

  void _showPublishSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24.0),
              topRight: Radius.circular(24.0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10.0,
                spreadRadius: 2.0,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40.0,
                  height: 4.0,
                  margin: const EdgeInsets.only(bottom: 20.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
                const Text(
                  '选择发布类型',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24.0),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _pickImages();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20.0),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16.0),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2575FC).withOpacity(0.3),
                                blurRadius: 8.0,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: const [
                              Icon(Icons.photo_library, color: Colors.white, size: 32.0),
                              SizedBox(height: 8.0),
                              Text(
                                '发布图文',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.0,
                                ),
                              ),
                              SizedBox(height: 4.0),
                              Text(
                                '最多5张照片',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16.0),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _pickVideo();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20.0),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16.0),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF4B2B).withOpacity(0.3),
                                blurRadius: 8.0,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: const [
                              Icon(Icons.video_library, color: Colors.white, size: 32.0),
                              SizedBox(height: 8.0),
                              Text(
                                '发布视频',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.0,
                                ),
                              ),
                              SizedBox(height: 4.0),
                              Text(
                                '选择单个视频',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10.0,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3.0,
                  ),
                  SizedBox(height: 20.0),
                  Text(
                    "正在处理媒体文件...",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.0,
                      decoration: TextDecoration.none,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _pickImages() async {
    _showLoadingDialog();
    List<XFile>? res;
    try {
      final ImagePicker picker = ImagePicker();
      res = await picker.pickMultiImage(imageQuality: 80);
    } catch (e) {
      debugPrint("ImagePicker pickMultiImage error: $e");
      widget.openSnackBar("选择图片失败: $e", 2);
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    if (res != null && res.isNotEmpty) {
      List<XFile> xFiles = res;
      if (xFiles.length > 5) {
        xFiles = xFiles.sublist(0, 5);
        widget.openSnackBar("最多只能选择5张照片", 2);
      }
      Navigator.pushNamed(context, "editMicro", arguments: {
        "openSnackBar": widget.openSnackBar,
        "uid": widget.auth,
        "initUserData": widget.initUserData,
        "initialMedias": xFiles,
      });
    }
  }

  void _pickVideo() async {
    _showLoadingDialog();
    XFile? res;
    try {
      final ImagePicker picker = ImagePicker();
      res = await picker.pickVideo(source: ImageSource.gallery);
    } catch (e) {
      debugPrint("ImagePicker pickVideo error: $e");
      widget.openSnackBar("选择视频失败: $e", 2);
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    if (res != null) {
      Navigator.pushNamed(context, "editMovie", arguments: {
        "openSnackBar": widget.openSnackBar,
        "platform": widget.platform,
        "uid": widget.auth,
        "initUserData": widget.initUserData,
        "initialVideo": res,
      });
    }
  }

  void _onPublishTapped() async {
    if (widget.auth != '') {
      close();
      _showPublishSheet();
    } else {
      jump("editMicro");
    }
  }

  void close(){
    _controller.reverse();
    setState(() {
      openBTN = false;
    });
  }

  void taggle(){
    setState(() {
      openBTN = !openBTN;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        height: 300,
        width: 300,
        child: ExpandableFab(
          expandAnimation: _expandAnimation,
          controller: _controller,
          fn: taggle,
          initialOpen: openBTN,
          distance: 72.0,
          children: [
            ActionButton(
              onPressed: () => jump("chat"),
              icon: const Icon(Icons.chat),
            ),
            ActionButton(
              onPressed: _onPublishTapped,
              icon: const Icon(Icons.post_add),
            ),
          ],
        )
      );
  }
}

@immutable
class ExpandableFab extends StatefulWidget {
  final bool initialOpen;
  final Animation<double> expandAnimation;
  final double distance;
  final AnimationController controller;
  final List<Widget> children;
  final Function fn;
  const ExpandableFab({
    Key? key,
    required this.initialOpen,
    required this.distance,
    required this.expandAnimation,
    required this.controller,
    required this.children,
    required this.fn,
  }): super(key: key);

  @override
  State<ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<ExpandableFab> {

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _toggle() {
    widget.fn();
    if (!widget.initialOpen) {
      widget.controller.forward();
    } else {
      widget.controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        alignment: Alignment.bottomRight,
        clipBehavior: Clip.none,
        children: [
          _buildTapToCloseFab(),
          ..._buildExpandingActionButtons(),
          _buildTapToOpenFab(),
        ],
      ),
    );
  }

  Widget _buildTapToCloseFab() {
    return SizedBox(
      width: 56.0,
      height: 56.0,
      child: Center(
        child: Material(
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          elevation: 4.0,
          child: InkWell(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                Icons.close,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildExpandingActionButtons() {
    final children = <Widget>[];
    final count = widget.children.length;
    final step = 90.0 / (count - 1);
    for (var i = 0, angleInDegrees = 0.0;
        i < count;
        i++, angleInDegrees += step) {
      children.add(
        _ExpandingActionButton(
          directionInDegrees: angleInDegrees,
          maxDistance: widget.distance,
          progress: widget.expandAnimation,
          child: widget.children[i],
        ),
      );
    }
    return children;
  }

  Widget _buildTapToOpenFab() {
    return IgnorePointer(
      ignoring: widget.initialOpen,
      child: AnimatedContainer(
        transformAlignment: Alignment.center,
        transform: Matrix4.diagonal3Values(
          widget.initialOpen ? 0.7 : 1.0,
          widget.initialOpen ? 0.7 : 1.0,
          1.0,
        ),
        duration: const Duration(milliseconds: 250),
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
        child: AnimatedOpacity(
          opacity: widget.initialOpen ? 0.0 : 1.0,
          curve: const Interval(0.25, 1.0, curve: Curves.easeInOut),
          duration: const Duration(milliseconds: 250),
          child: FloatingActionButton(
            onPressed: _toggle,
            heroTag: 4,
            child: const Icon(Icons.create),
          ),
        ),
      ),
    );
  }
}

@immutable
class _ExpandingActionButton extends StatelessWidget {
  final double directionInDegrees;
  final double maxDistance;
  final Animation<double> progress;
  final Widget child;

  const _ExpandingActionButton({
    required this.directionInDegrees,
    required this.maxDistance,
    required this.progress,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, child) {
        final offset = Offset.fromDirection(
          directionInDegrees * (math.pi / 180.0),
          progress.value * maxDistance,
        );
        return Positioned(
          right: 4.0 + offset.dx,
          bottom: 4.0 + offset.dy,
          child: Transform.rotate(
            angle: (1.0 - progress.value) * math.pi / 2,
            child: child,
          ),
        );
      },
      child: FadeTransition(
        opacity: progress,
        child: child,
      ),
    );
  }
}

@immutable
class ActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget icon;

  const ActionButton({
    Key? key,
    required this.onPressed,
    required this.icon,
  }): super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.secondary,
      elevation: 4.0,
      child: Column(
        children: [
          IconButton(
            onPressed: onPressed,
            icon: icon,
            color: theme.colorScheme.onSecondary,
          )
      ]),
    );
  }
}