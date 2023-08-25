import 'dart:io';

import 'package:file_selector/file_selector.dart' hide XFile;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart' hide XFile;
import 'package:share_plus/share_plus.dart';

import 'image_previews.dart';

void main() {
  runApp(const DemoApp());
}

class DemoApp extends StatefulWidget {
  const DemoApp({Key? key}) : super(key: key);

  @override
  DemoAppState createState() => DemoAppState();
}

class DemoAppState extends State<DemoApp> {
  List<String> mediaNames = [];
  List<String> mediaPaths = [];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Share Plus Plugin Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0x9f4376f8),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Share Plus Plugin Demo'),
          elevation: 4,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 16),
              MediaPreviews(mediaPaths, onDelete: _onDeleteImage),
              ElevatedButton.icon(
                label: const Text('Add media'),
                onPressed: _addMedia,
                icon: const Icon(Icons.add),
              ),
              const SizedBox(height: 32),
              Builder(
                builder: (BuildContext context) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: mediaPaths.isEmpty ? null : () => _onShare(context),
                    child: const Text('Share'),
                  );
                },
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (BuildContext context) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: mediaPaths.isEmpty ? null : () => _onShareWithResult(context),
                    child: const Text('Share With Result'),
                  );
                },
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (BuildContext context) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: mediaPaths.isEmpty ? null : () => _onShareXFileFromAssets(context),
                    child: const Text('Share XFile from Assets'),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addMedia() async {
    // Using `package:image_picker` to get image from gallery.
    if (!kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows)) {
      // Using `package:file_selector` on windows, macos & Linux, since `package:image_picker` is not supported.

      const XTypeGroup imageTypeGroup = XTypeGroup(
        label: 'images',
        extensions: <String>['jpg', 'jpeg', 'png', 'gif'],
      );
      const XTypeGroup videoTypeGroup = XTypeGroup(
        label: 'videos',
        extensions: <String>['mp4'],
      );
      final file = await openFile(acceptedTypeGroups: <XTypeGroup>[
        imageTypeGroup,
        videoTypeGroup,
      ]);

      if (file != null) {
        setState(() {
          mediaPaths.add(file.path);
          mediaNames.add(file.name);
        });
      }
    } else {
      final imagePicker = ImagePicker();
      final pickedFile = await imagePicker.pickMedia();
      if (pickedFile != null) {
        setState(() {
          mediaPaths.add(pickedFile.path);
          mediaNames.add(pickedFile.name);
        });
      }
    }
  }

  void _onDeleteImage(int position) {
    setState(() {
      mediaPaths.removeAt(position);
      mediaNames.removeAt(position);
    });
  }

  Future<void> _onShare(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;

    if (mediaPaths.isNotEmpty) {
      final files = <XFile>[];
      for (var i = 0; i < mediaPaths.length; i++) {
        files.add(XFile(mediaPaths[i], name: mediaNames[i]));
      }
      await Share.shareXFiles(files, sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size);
    }
  }

  Future<void> _onShareWithResult(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    ShareResult shareResult;
    if (mediaPaths.isNotEmpty) {
      final files = <XFile>[];
      for (var i = 0; i < mediaPaths.length; i++) {
        files.add(XFile(mediaPaths[i], name: mediaNames[i]));
      }
      shareResult = await Share.shareXFiles(files, sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size);
      scaffoldMessenger.showSnackBar(getResultSnackBar(shareResult));
    }
  }

  Future<void> _onShareXFileFromAssets(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final data = await rootBundle.load('assets/kirby.gif');
    final buffer = data.buffer;
    final shareResult = await Share.shareXFiles(
      [
        XFile.fromData(
          buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          name: 'flutter_logo.png',
          mimeType: 'image/png',
        ),
      ],
      sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
    );

    scaffoldMessenger.showSnackBar(getResultSnackBar(shareResult));
  }

  SnackBar getResultSnackBar(ShareResult result) {
    return SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Share result: ${result.status}"),
          if (result.status == ShareResultStatus.success) Text("Shared to: ${result.raw}")
        ],
      ),
    );
  }
}
