import 'dart:math';

import 'package:flutter/material.dart';

class ZigZagAnimationDemo extends StatefulWidget {
  const ZigZagAnimationDemo({super.key});
  static String routeName = 'misc/zigzag_animation';
  @override
  State<ZigZagAnimationDemo> createState() => _ZigZagAnimationDemoState();
}

class _ZigZagAnimationDemoState extends State<ZigZagAnimationDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final Animation<double> animation;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );

    animation = Tween<double>(begin: 0, end: 300).animate(controller)
      ..addListener(() {
        setState(() {
          // 애니메이션 값 변경을 반영하기 위해 강제로 재구축합니다.
        });
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          controller.reverse();
        } else if (status == AnimationStatus.dismissed) {
          controller.forward();
        }
      });

    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZigZag Animation Demo'),
      ),
      body: Align(
          alignment: Alignment.topCenter,
          child: Transform.translate(
              offset: Offset(
                sin(animation.value / 20) * 20,
                animation.value,
              ),
              child: Image.asset('assets/ghost.png',
                  height: MediaQuery.of(context).size.height / 4))),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
