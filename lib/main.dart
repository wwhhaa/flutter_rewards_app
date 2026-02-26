import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_tapjoy/flutter_tapjoy.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rewards App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const WebViewScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController controller;
  bool _isLoading = true;
  final TJPlacement _offerwallPlacement = TJPlacement(name: "Tasks");

  void _connectionResultHandler(TJConnectionResult result) {
    if (result == TJConnectionResult.connected) {
      TapJoyPlugin.shared.addPlacement(_offerwallPlacement);
    }
  }

  @override
  void initState() {
    super.initState();
    TapJoyPlugin.shared.connect(
      androidApiKey: "6cc70fe9-d681-4cda-b98f-70b3ed33fb0f",
      iOSApiKey: "",
      debug: false,
    );
    TapJoyPlugin.shared.setConnectionResultHandler(_connectionResultHandler);

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {},
        ),
      )
      ..addJavaScriptChannel(
        'TapjoyBridge',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'showOfferwall') {
            _offerwallPlacement.requestContent();
            _offerwallPlacement.setHandler((
              dynamic placement,
              dynamic handlerName,
              dynamic error,
            ) {
              if (handlerName == 'contentIsReady') {
                _offerwallPlacement.showPlacement();
              }
            });
          }
        },
      )
      // IMPORTANT: Replace this with your computer's IP address for local testing (e.g., http://192.168.1.X:3000)
      // OR use the hosted URL once deployed.
      // For Android Emulator, 10.0.2.2 usually maps to localhost.
      ..loadRequest(Uri.parse('https://hid-wheat.vercel.app/'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: controller),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
