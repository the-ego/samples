import 'dart:io';
import 'dart:ui' as ui;

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
  final GlobalKey _globalKey = GlobalKey();
  VideoPlayerController? _videoPlayerController;
  String _videoPath = '';
  String scale = '100:100';
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
      body: SafeArea(
        child: Center(
          child: FutureBuilder(
            future: _captureAnimation(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Row(
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
                            await _fileToVideo(snapshot.data as List<String>);
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
                          ? AspectRatio(
                              aspectRatio: _videoPlayerController!.value.aspectRatio,
                              child: VideoPlayer(_videoPlayerController!),
                            )
                          : const SizedBox.shrink(),
                    ),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 5.0,
                          mainAxisSpacing: 5.0,
                        ),
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          String item = snapshot.data![index];
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
                );
              } else {
                return Column(
                  children: [
                    ElevatedButton(
                      onPressed: _captureAnimation,
                      child: const Text('캡쳐하기'),
                    ),
                    RepaintBoundary(
                      key: _globalKey,
                      child: AnimatedBuilder(
                        animation: _colorAnimation,
                        builder: (context, child) {
                          return Container(
                            width: 200,
                            height: 200,
                            color: _colorAnimation.value,
                            child: const Center(child: Text('애니메이션')),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Future<List<String>?> _captureAnimation() async {
    List<String> capturedImages = [];
    // WidgetsBinding.instance.addPostFrameCallback((_) async {
    final directory = await getTemporaryDirectory();
    final totalFrames = 60;

    for (int i = 0; i < totalFrames; i++) {
      _animationController.value = i / (totalFrames - 1);
      await Future.delayed(const Duration(milliseconds: 16));

      RenderRepaintBoundary? boundary = _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      scale = '${boundary?.size.width.toString()}: ${boundary?.size.height.toString()}';
      if (boundary == null) continue;
      ui.Image image = await boundary.toImage();
      final imagePath = '${directory.path}/capture_${i.toString().padLeft(3, '0')}.png'; // 숫자를 3자리로 포맷
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(
          await image.toByteData(format: ui.ImageByteFormat.png).then((byteData) => byteData!.buffer.asUint8List()));
      capturedImages.add(imagePath); // 경로를 리스트에 추가
    }
    // });
    return capturedImages;
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
    final ffmpegCommand = generateEncodeVideoScript(imagePaths, videoFile.path, 'mpeg4', 'yuv420p', '');
    FFmpegKit.executeAsync(ffmpegCommand, (session) async {
      final state = FFmpegKitConfig.sessionStateToString(await session.getState());
      final returnCode = await session.getReturnCode();
      final failStackTrace = await session.getFailStackTrace();
      final duration = await session.getDuration();

      if (ReturnCode.isSuccess(returnCode)) {
        print("Encode completed successfully in $duration milliseconds; playing video.");
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
      List<String> imagePaths, String videoFilePath, String videoCodec, String pixelFormat, String customOptions) {
    String inputOptions = "";
    String filterOptions = "";

    for (int i = 0; i < imagePaths.length; i++) {
      inputOptions += "-loop 1 -t 1 -i '${imagePaths[i]}' ";
      filterOptions += "[$i:v]scale=$scale,setsar=1[v$i]; ";
    }

    String concatOptions = "";
    for (int i = 0; i < imagePaths.length; i++) {
      concatOptions += "[v$i]";
    }

    concatOptions += "concat=n=${imagePaths.length}:v=1:a=0[v]";

    return "$inputOptions-filter_complex \"$filterOptions$concatOptions\" -map [v] -c:v $videoCodec -pix_fmt $pixelFormat -b:v 3000k  -r 30 $customOptions$videoFilePath";
  }
}
