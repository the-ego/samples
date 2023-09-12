import 'dart:io';
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CaptureWidget(),
    );
  }
}

class CaptureWidget extends StatefulWidget {
  @override
  _CaptureWidgetState createState() => _CaptureWidgetState();
}

class _CaptureWidgetState extends State<CaptureWidget> with SingleTickerProviderStateMixin {
  List<String> _capturedImages = [];
  final GlobalKey _globalKey = GlobalKey();
  VideoPlayerController? _videoPlayerController;
  String _videoPath = '';
  late AnimationController _animationController;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _colorAnimation = ColorTween(
      begin: Colors.blue,
      end: Colors.red,
    ).animate(_animationController);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            RepaintBoundary(
              key: _globalKey,
              child: AnimatedBuilder(
                animation: _colorAnimation,
                builder: (context, child) {
                  return Container(
                    width: 200,
                    height: 200,
                    color: _colorAnimation.value,
                    child: Center(child: Text('애니메이션')),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            if (_videoPath.isNotEmpty)
              ElevatedButton(
                child: const Text("Save"),
                onPressed: () async {
                  final result = await ImageGallerySaver.saveFile(_videoPath);
                  if (result['isSuccess']) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장 완료! ✅')));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장 실패! ❌')));
                  }
                },
              ),
            ElevatedButton(
              child: Text('캡쳐하기'),
              onPressed: _captureAnimation,
            ),
            if (_videoPath.isNotEmpty) ...[
              SizedBox(height: 20),
              ElevatedButton(
                  child: Text('비디오 보기'),
                  onPressed: () async {
                    if (!(await File(_videoPath).exists())) {
                      print("파일이 존재하지 않습니다.");
                      return;
                    }
                    _videoPlayerController = VideoPlayerController.file(File(_videoPath))
                      ..initialize().then((_) {
                        setState(() {
                          _videoPlayerController?.play();
                        });
                      }, onError: (error) {
                        print("Error initializing video player: $error");
                      });
                  }),
              Container(
                child: _videoPlayerController?.value.isInitialized ?? false
                    ? AspectRatio(
                        aspectRatio: _videoPlayerController!.value.aspectRatio,
                        child: VideoPlayer(_videoPlayerController!),
                      )
                    : SizedBox(),
              )
            ],
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 5.0,
                  mainAxisSpacing: 5.0,
                ),
                itemCount: _capturedImages.length,
                itemBuilder: (context, index) {
                  return Image.file(File(_capturedImages[index]));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _captureAnimation() async {
    _capturedImages = [];
    final directory = await getTemporaryDirectory();
    final totalFrames = 60;

    for (int i = 0; i < totalFrames; i++) {
      _animationController.value = i / (totalFrames - 1);
      await Future.delayed(Duration(milliseconds: 16));

      RenderRepaintBoundary? boundary = _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) continue;
      ui.Image image = await boundary.toImage();
      final imagePath = '${directory.path}/capture_${i.toString().padLeft(3, '0')}.png'; // 숫자를 3자리로 포맷
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(
          await image.toByteData(format: ui.ImageByteFormat.png).then((byteData) => byteData!.buffer.asUint8List()));
      _capturedImages.add(imagePath); // 경로를 리스트에 추가
    }

    _videoPath = '${directory.path}/output.mp4';
    await FFmpegKit.execute(
        '-y -framerate 30 -i "${directory.path}/capture_%03d.png" -c:v libx264 -pix_fmt yuv420p -r 30 $_videoPath');

    setState(() {});
  }

  @override
  void dispose() {
    super.dispose();
    _animationController.dispose();
    _videoPlayerController?.dispose();
  }
}
