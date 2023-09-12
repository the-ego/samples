import 'dart:io';

import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    writeAsset();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: RenderPage(),
    );
  }
}

List<String> _assets = [
  'assets/bg_0.png',
  'assets/bg_1.png',
  'assets/bg_2.png',
  'assets/bg_3.png',
  'assets/bg_4.png',
  'assets/bg_5.png',
  'assets/bg_6.png',
  'assets/bg_7.png',
  'assets/bg_8.png'
];
Future<String> assetPath(String assetName) async {
  return join((await tempDirectory).path, assetName);
}

Future<Directory> get documentsDirectory async {
  return await getApplicationDocumentsDirectory();
}

Future<Directory> get tempDirectory async {
  return await getTemporaryDirectory();
}

Future<List<String>> writeAsset() async {
  final directory = await tempDirectory;
  List<String> capturedImages = [];
  for (var assetName in _assets) {
    final assetByteData = await rootBundle.load(assetName);
    final buffer = assetByteData.buffer.asUint8List();
    final imagePath = '${directory.path}/${assetName.split('/').last}';
    final file = File(imagePath);
    await file.writeAsBytes(buffer);
    capturedImages.add(imagePath);
  }
  return capturedImages;
}

class RenderPage extends StatefulWidget {
  const RenderPage({super.key});

  @override
  _RenderPageState createState() => _RenderPageState();
}

class _RenderPageState extends State<RenderPage> with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoPlayerController;
  String _videoPath = '';
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: FutureBuilder(
            future: writeAsset(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
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
                        itemCount: snapshot.data?.length,
                        itemBuilder: (context, index) {
                          String item = snapshot.data![index];
                          return Stack(
                            children: [
                              Image.file(File(item)),
                              Text(item.split('/').last.split('.').first,
                                  style: const TextStyle(color: Colors.white, fontSize: 20)),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                );
              } else {
                return const CircularProgressIndicator();
              }
            },
          ),
        ),
      ),
    );
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
      if (_videoPlayerController != null) {
        await _videoPlayerController!.pause();
      }
    }
    File target = await getVideoFile();
    deleteFile(target);

    final ffmpegCommand = generateEncodeVideoScript(imagePaths, target.path, 'mpeg4', 'yuv420p', '');

    FFmpegKit.executeAsync(ffmpegCommand, (session) async {
      final state = FFmpegKitConfig.sessionStateToString(await session.getState());
      final returnCode = await session.getReturnCode();
      final failStackTrace = await session.getFailStackTrace();
      final duration = await session.getDuration();

      if (ReturnCode.isSuccess(returnCode)) {
        print("Encode completed successfully in $duration milliseconds; playing video.");
        _videoPlayerController = VideoPlayerController.file(target)
          ..initialize().then((_) {
            setState(() {});
          });
        await _videoPlayerController!.play();
        _videoPath = target.path;
      } else {
        print("Encode failed with state $state and rc $returnCode.");
      }
    }, (log) => print(log.getMessage()), (statistics) {})
        .then((session) => print("Async FFmpeg process started with sessionId ${session.getSessionId()}."));
  }

  @override
  void dispose() {
    super.dispose();
    _videoPlayerController?.dispose();
  }

  generateEncodeVideoScript(
      List<String> imagePaths, String videoFilePath, String videoCodec, String pixelFormat, String customOptions) {
    String inputOptions = "";
    String filterOptions = "";

    for (int i = 0; i < imagePaths.length; i++) {
      inputOptions += "-loop 1 -t 1 -i '${imagePaths[i]}' ";
      filterOptions += "[$i:v]scale=300:464,setsar=1[v$i]; ";
    }

    String concatOptions = "";
    for (int i = 0; i < imagePaths.length; i++) {
      concatOptions += "[v$i]";
    }

    concatOptions += "concat=n=${imagePaths.length}:v=1:a=0[v]";

    return "$inputOptions-filter_complex \"$filterOptions$concatOptions\" -map [v] -c:v $videoCodec -pix_fmt $pixelFormat -b:v 3000k  -r 30 $customOptions$videoFilePath";
  }
}
