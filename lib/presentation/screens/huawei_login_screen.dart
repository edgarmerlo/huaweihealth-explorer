import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../data/services/huawei_cloud_service.dart';

class HuaweiLoginScreen extends StatefulWidget {
  const HuaweiLoginScreen({super.key});

  @override
  State<HuaweiLoginScreen> createState() => _HuaweiLoginScreenState();
}

class _HuaweiLoginScreenState extends State<HuaweiLoginScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _loadingProgress = 0.0;
  bool _hasSavedSession = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 14; SM-S911B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _loadingProgress = progress / 100.0;
            });
          },
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
            _checkAuthSuccess(url);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
            _checkAuthSuccess(url);
          },
          onNavigationRequest: (NavigationRequest request) {
            _checkAuthSuccess(request.url);
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://id1.cloud.huawei.com/CAS/portal/loginAuth.html'));
  }

  Future<void> _checkAuthSuccess(String url) async {
    if (_hasSavedSession) return;

    // Successful login typically redirects to cloud.huawei.com, health portal, or CAS success
    final isSuccessUrl = url.contains('cloud.huawei.com') ||
                         url.contains('health.huawei.com') ||
                         url.contains('home.html') ||
                         url.contains('portal/success');

    try {
      // Check cookies via JavaScript
      final cookiesString = await _controller.runJavaScriptReturningResult('document.cookie') as String?;
      
      if (cookiesString != null && cookiesString.isNotEmpty && cookiesString != '""') {
        final sanitized = cookiesString.replaceAll('"', '');
        final cookieMap = <String, String>{};
        
        final parts = sanitized.split(';');
        for (final p in parts) {
          final kv = p.split('=');
          if (kv.length == 2) {
            cookieMap[kv[0].trim()] = kv[1].trim();
          }
        }

        final hasAuthCookie = cookieMap.containsKey('CAS_ST') ||
                              cookieMap.containsKey('JSESSIONID') ||
                              cookieMap.containsKey('HUAWEI_ID') ||
                              cookieMap.containsKey('login_token') ||
                              isSuccessUrl;

        if (hasAuthCookie && cookieMap.isNotEmpty && isSuccessUrl) {
          _hasSavedSession = true;
          await HuaweiCloudService.instance.saveSession(cookieMap);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Connected to Huawei ID successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true);
          }
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log in with Huawei ID'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _controller.reload(),
          ),
        ],
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3.0),
                child: LinearProgressIndicator(
                  value: _loadingProgress,
                  color: Colors.redAccent,
                  backgroundColor: Colors.grey.shade200,
                ),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
