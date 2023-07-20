import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class AnimatedPositionedDemo extends StatefulWidget {
  const AnimatedPositionedDemo({super.key});
  static String routeName = 'misc/animated_positioned';

  @override
  State<AnimatedPositionedDemo> createState() => _AnimatedPositionedDemoState();
}

class _AnimatedPositionedDemoState extends State<AnimatedPositionedDemo> {
  late double topPosition;
  late double leftPosition;
  Timer? timer;

  double generateTopPosition(double top) => Random().nextDouble() * top;

  double generateLeftPosition(double left) => Random().nextDouble() * left;

  @override
  void initState() {
    super.initState();
    topPosition = generateTopPosition(30);
    leftPosition = generateLeftPosition(30);
    timer = Timer.periodic(const Duration(seconds: 10), (Timer t) {
      final size = MediaQuery.of(context).size;
      final appBar = AppBar(title: const Text('AnimatedPositioned'));
      final topPadding = MediaQuery.of(context).padding.top;
      changePosition(
          size.height -
              (appBar.preferredSize.height + topPadding + 50),
          size.width - 150);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void changePosition(double top, double left) {
    setState(() {
      topPosition = generateTopPosition(top);
      leftPosition = generateLeftPosition(left);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final appBar = AppBar(title: const Text('AnimatedPositioned'));
    final topPadding = MediaQuery.of(context).padding.top;
    // AnimatedPositioned animates changes to a widget's position within a Stack
    return Scaffold(
      appBar: appBar,
      body: SizedBox(
        height: size.height,
        width: size.width,
        child: Stack(
          children: [
            AnimatedPositioned(
              top: topPosition,
              left: leftPosition,
              duration: const Duration(seconds: 1),
              child: GestureDetector(
                onTap: () => changePosition(
                    size.height -
                        (appBar.preferredSize.height + topPadding + 50),
                    size.width - 150),
                child: Image.asset(
                  'assets/ghost.png',
                  fit: BoxFit.cover,
                  height: 150,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
