import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

  // Game IDs from Unity Ads dashboard
  final String _androidGameId = '6055807';
  final String _iosGameId = '6055806';

  // Ad Unit IDs
  final String _rewardedAdUnitId = 'Rewarded_Android';
  final String _rewardedIosAdUnitId = 'Rewarded_iOS';

  String get gameId => !kIsWeb && Platform.isIOS ? _iosGameId : _androidGameId;
  String get rewardedAdUnitId =>
      !kIsWeb && Platform.isIOS ? _rewardedIosAdUnitId : _rewardedAdUnitId;

  @override
  void initState() {
    super.initState();
    _initUnityAds();

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
        'AdsBridge',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'showRewardedVideo') {
            _showRewardedAd();
          }
        },
      )
      ..loadRequest(
        Uri.parse('http://10.0.2.2:3001/auth/login'),
      ); // Using local deployment to test
  }

  void _initUnityAds() {
    UnityAds.init(
      gameId: gameId,
      testMode: false,
      onComplete: () {
        debugPrint('Unity Ads Initialization Complete');
        _loadRewardedAd();
      },
      onFailed: (error, message) {
        debugPrint('Unity Ads Initialization Failed: $error $message');
      },
    );
  }

  void _loadRewardedAd() {
    UnityAds.load(
      placementId: rewardedAdUnitId,
      onComplete: (placementId) {
        debugPrint('Unity Rewarded Ad loaded successfully: $placementId');
      },
      onFailed: (placementId, error, message) {
        debugPrint(
          'Unity Rewarded Ad failed to load: $placementId $error $message',
        );
      },
    );
  }

  void _showRewardedAd() {
    UnityAds.showVideoAd(
      placementId: rewardedAdUnitId,
      onStart: (placementId) => debugPrint('Video Ad $placementId started'),
      onClick: (placementId) => debugPrint('Video Ad $placementId click'),
      onSkipped: (placementId) {
        debugPrint('Video Ad $placementId skipped');
        // Tell UI ad was skipped
        controller.runJavaScript("""
          if (document.getElementById('watch-ad-btn')) {
            document.getElementById('watch-ad-btn').disabled = false;
            document.getElementById('watch-ad-btn').innerHTML = '<i class="fas fa-play-circle"></i> مشاهدة إعلان';
          }
          if (document.getElementById('ad-msg')) {
            document.getElementById('ad-msg').textContent = 'لم تكتمل مشاهدة الإعلان.';
            document.getElementById('ad-msg').style.color = '#ff4d4d';
          }
        """);
        _loadRewardedAd(); // Load next
      },
      onComplete: (placementId) {
        debugPrint('Video Ad $placementId completed');
        // Reward user
        controller.runJavaScript(
          "if (window.onVideoRewarded) window.onVideoRewarded();",
        );
        _loadRewardedAd(); // Load next
      },
      onFailed: (placementId, error, message) {
        debugPrint('Video Ad $placementId failed: $error $message');
        controller.runJavaScript("""
          if (document.getElementById('watch-ad-btn')) {
            document.getElementById('watch-ad-btn').disabled = false;
            document.getElementById('watch-ad-btn').innerHTML = '<i class="fas fa-play-circle"></i> مشاهدة إعلان';
          }
          if (document.getElementById('ad-msg')) {
            document.getElementById('ad-msg').textContent = 'تعذر عرض الإعلان: $message';
            document.getElementById('ad-msg').style.color = '#ff4d4d';
          }
        """);
        _loadRewardedAd(); // Attempt to reload
      },
    );
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
