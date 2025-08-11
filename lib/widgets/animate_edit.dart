import 'package:flutter/material.dart';
import 'dart:math' as math;

class MyAnimateEdit extends StatefulWidget {
  final Function openSnackBar;
  final String auth;
  final dynamic platform;
  final dynamic socket;
  final Function initUserData;
  const MyAnimateEdit({
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
          distance: 112.0,
          children: [
            ActionButton(
              onPressed: () => jump("editMicro"),
              icon: const Icon(Icons.image),
            ),
            ActionButton(
              onPressed: () => jump("editMovie"),
              icon: const Icon(Icons.movie_creation),
            ),
            ActionButton(
              onPressed: () => jump("chat"),
              icon: const Icon(Icons.chat),
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