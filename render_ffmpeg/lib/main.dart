import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
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
  final GlobalKey _containerKey = GlobalKey();
  VideoPlayerController? _videoPlayerController;
  String _videoPath = '';
  double size = 200;
  double ratio = 3;
  String FILE_NAME = 'capture';
  int TOTAL_FRAME = 60;
  String get scale => '${size * ratio}:${size * ratio}';
  Image? img;
  late AnimationController _animationController;
  late Animation<Color?> _colorAnimation;
  Duration animationDuration = const Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: animationDuration,
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(
                onDoubleTap: _captureAnimation,
                child: RepaintBoundary(
                  key: _containerKey,
                  child: AnimatedBuilder(
                    animation: _colorAnimation,
                    builder: (context, child) {
                      return SizedBox(
                        width: size,
                        height: size,
                        child: Stack(
                          children: [
                            Container(
                              width: size,
                              height: size,
                              color: _colorAnimation.value,
                            ),
                            const Center(child: Text('애니메이션'))
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                    child: const Text('to Video'),
                    onPressed: () async {
                      await _fileToVideo(capturedImages);
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
                    },
                  ),
                ],
              ),
              Container(
                child: _videoPlayerController?.value.isInitialized ?? false
                    ? GestureDetector(
                        onDoubleTap: () => _videoPlayerController?.play(),
                        child: SizedBox(
                          height: 200,
                          width: 200,
                          child: AspectRatio(
                            aspectRatio: _videoPlayerController!.value.aspectRatio,
                            child: VideoPlayer(_videoPlayerController!),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 400,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 5.0,
                    mainAxisSpacing: 5.0,
                  ),
                  itemCount: capturedImages.length,
                  itemBuilder: (context, index) {
                    String item = capturedImages[index];
                    return Stack(
                      children: [
                        Image.file(File(item)),
                        Text(
                          item.split('/').last.split('.').first,
                          style: const TextStyle(color: Colors.white, fontSize: 20),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Directory? directory;
  List<String> capturedImages = [];
  void _captureAnimation() async {
    capturedImages = [];
    // WidgetsBinding.instance.addPostFrameCallback((_) async {
    directory = await getTemporaryDirectory();

    Duration duration = animationDuration ~/ TOTAL_FRAME;
    for (int i = 0; i < TOTAL_FRAME; i++) {
      _animationController.value = i / (TOTAL_FRAME - 1);
      Uint8List? byte = await capture(pixelRatio: ratio, delay: duration);

      if (byte == null) continue;
      final imagePath = '${directory?.path}/$FILE_NAME${(i + 1).toString()}.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(byte);
      capturedImages.add(imagePath); // 경로를 리스트에 추가
    }

    setState(() {});
  }

  @override
  void dispose() {
    super.dispose();
    _animationController.dispose();
    _videoPlayerController?.dispose();
  }

  Future<File> getVideoFile() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    return File("${documentsDirectory.path}/video.mp4");
  }

  Future<Uint8List?> capture({double pixelRatio = 3, Duration delay = const Duration(milliseconds: 20)}) {
    return Future.delayed(delay, () async {
      try {
        ui.Image? image = await captureAsUiImage(
          pixelRatio,
          Duration.zero,
        );
        ByteData? byteData = await image?.toByteData(format: ui.ImageByteFormat.png);
        image?.dispose();

        Uint8List? pngBytes = byteData?.buffer.asUint8List();

        return pngBytes;
      } on Exception {
        throw (Exception);
      }
    });
  }

  Future<ui.Image?> captureAsUiImage(double pixelRatio, Duration delay) {
    return Future.delayed(delay, () async {
      try {
        var findRenderObject = _containerKey.currentContext?.findRenderObject();
        if (findRenderObject == null) {
          return null;
        }
        RenderRepaintBoundary boundary = findRenderObject as RenderRepaintBoundary;
        BuildContext? context = _containerKey.currentContext;
        if (context == null) {
          return null;
        }
        ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
        return image;
      } on Exception {
        throw (Exception);
      }
    });
  }

  void deleteFile(File file) {
    file.exists().then((exists) {
      if (exists) {
        try {
          file.delete();
          _videoPath = '';
        } on Exception catch (e, stack) {
          print("Exception thrown inside deleteFile block. $e");
          print(stack);
        }
      }
    });
  }

  Future<void> _fileToVideo(List<String> imagePaths) async {
    if (Platform.isAndroid || Platform.isIOS) {
      if (await FFmpegKitConfig.getFFmpegVersion() == null) {
        await FFmpegKitConfig.init();
      }
    }

    final videoFile = await getVideoFile();
    deleteFile(videoFile);
    final ffmpegCommand = generateEncodeVideoScript(videoFile.path);
    FFmpegKit.executeAsync(ffmpegCommand, (session) async {
      final state = FFmpegKitConfig.sessionStateToString(await session.getState());
      final returnCode = await session.getReturnCode();
      final failStackTrace = await session.getFailStackTrace();
      final duration = await session.getDuration();

      if (ReturnCode.isSuccess(returnCode)) {
        print("Encode completed successfully in $duration seconds; playing video.");
        _videoPlayerController = VideoPlayerController.file(videoFile)
          ..initialize().then((_) {
            setState(() {});
          });
        await _videoPlayerController!.play();
        _videoPath = videoFile.path;
      } else {
        print("Encode failed with state $state and rc $returnCode.");
      }
    }, (log) => print(log.getMessage()), (statistics) {})
        .then((session) => print("Async FFmpeg process started with sessionId ${session.getSessionId()}."));
  }

  generateEncodeVideoScript(
    String videoFilePath,
  ) {
    return "-framerate $TOTAL_FRAME/${animationDuration.inSeconds} -i '${directory?.path}/$FILE_NAME%d.png' -vf: scale=$scale -q 1 -b:v 2M -maxrate 2M -bufsize 1M  $videoFilePath";
  }
}
