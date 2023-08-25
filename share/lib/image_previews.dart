import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart'; // 비디오 플레이어 패키지

class MediaPreviews extends StatelessWidget {
  final List<String> mediaPaths;
  final Function(int)? onDelete;

  const MediaPreviews(this.mediaPaths, {Key? key, this.onDelete}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (mediaPaths.isEmpty) {
      return const SizedBox.shrink();
    }

    final mediaWidgets = <Widget>[];
    for (var i = 0; i < mediaPaths.length; i++) {
      final isVideo = mediaPaths[i].toLowerCase().endsWith('.mp4'); // 예시로 mp4만 판별합니다.
      if (isVideo) {
        mediaWidgets.add(_VideoPreview(
          mediaPaths[i],
          onDelete: onDelete != null ? () => onDelete!(i) : null,
        ));
      } else {
        mediaWidgets.add(_ImagePreview(
          mediaPaths[i],
          onDelete: onDelete != null ? () => onDelete!(i) : null,
        ));
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: mediaWidgets),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final String imagePath;
  final VoidCallback? onDelete;

  const _ImagePreview(this.imagePath, {Key? key, this.onDelete}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final imageFile = File(imagePath);
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Stack(
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 200,
              maxHeight: 200,
            ),
            child: kIsWeb ? Image.network(imagePath) : Image.file(imageFile),
          ),
          if (onDelete != null)
            Positioned(
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: FloatingActionButton(
                    backgroundColor: Colors.red, onPressed: onDelete, child: const Icon(Icons.delete)),
              ),
            ),
        ],
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  final String videoPath;
  final VoidCallback? onDelete;

  const _VideoPreview(this.videoPath, {Key? key, this.onDelete}) : super(key: key);

  @override
  _VideoPreviewState createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath));
    _controller.addListener(() {
      setState(() {});
    });
    _controller.setLooping(true);
    _controller.initialize().then((_) => setState(() {}));
    _controller.play();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Stack(
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 200,
              maxHeight: 200,
            ),
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
          if (widget.onDelete != null)
            Positioned(
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: FloatingActionButton(
                    backgroundColor: Colors.red, onPressed: widget.onDelete, child: const Icon(Icons.delete)),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
