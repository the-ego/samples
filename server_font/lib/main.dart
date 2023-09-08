import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

Future<ByteData> fetchFont(String url) async {
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    return ByteData.view(response.bodyBytes.buffer);
  } else {
    throw Exception('Failed to load font');
  }
}

void main() async {
  var fontUrls = {
    'GmarketSansBold': 'https://dingdongu.s3.ap-northeast-2.amazonaws.com/dev/fonts/gmarket/GmarketSansBold.otf',
    'GmarketSansLight': 'https://dingdongu.s3.ap-northeast-2.amazonaws.com/dev/fonts/gmarket/GmarketSansLight.otf',
    'GmarketSansMedium': 'https://dingdongu.s3.ap-northeast-2.amazonaws.com/dev/fonts/gmarket/GmarketSansMedium.otf',
    'Cafe24Ssurround':
        'https://dingdongu.s3.ap-northeast-2.amazonaws.com/dev/fonts/cafe24s-surround/Cafe24Ssurround-v2.0.ttf',
    'MaruBuri-Bold': 'https://dingdongu.s3.ap-northeast-2.amazonaws.com/dev/fonts/maruburi/MaruBuri-Bold.ttf',
    'Montserrat': 'https://github.com/google/fonts/raw/main/ofl/meddon/Meddon.ttf',
  };

  for (var fontName in fontUrls.keys) {
    var fontLoader = FontLoader(fontName);
    fontLoader.addFont(fetchFont(fontUrls[fontName] ?? ''));
    await fontLoader.load();
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Custom Fonts',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _selectedFont = 'Montserrat';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Custom Fonts')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'This is a sample text',
              style: TextStyle(fontFamily: _selectedFont, fontSize: 24),
            ),
            SizedBox(height: 20),
            DropdownButton<String>(
              value: _selectedFont,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedFont = newValue!;
                });
              },
              items: <String>[
                'GmarketSansBold',
                'GmarketSansLight',
                'GmarketSansMedium',
                'Cafe24Ssurround',
                'MaruBuri-Bold',
                'Montserrat',
              ].map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
