import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

const webBaseUrl = String.fromEnvironment(
  'WEB_BASE_URL',
  defaultValue: 'https://morejob-fe.vercel.app',
);

class WebFeature {
  const WebFeature(this.title, this.path, this.icon);
  final String title;
  final String path;
  final IconData icon;
}

const publicFeatures = <WebFeature>[
  WebFeature('Trang chủ và tin tuyển dụng', '/', Icons.home_outlined),
  WebFeature('Tất cả tiện ích', '/tools', Icons.widgets_outlined),
  WebFeature('Trắc nghiệm MBTI', '/tools/mbti', Icons.psychology_outlined),
  WebFeature('Trắc nghiệm DISC', '/tools/disc', Icons.groups_outlined),
  WebFeature('Đa trí thông minh MI', '/tools/mi', Icons.lightbulb_outline),
  WebFeature(
    'Tính lương Gross–Net',
    '/tools/gross-net',
    Icons.calculate_outlined,
  ),
  WebFeature(
    'Thuế thu nhập cá nhân',
    '/tools/income-tax',
    Icons.receipt_long_outlined,
  ),
  WebFeature(
    'Bảo hiểm xã hội',
    '/tools/social-insurance',
    Icons.health_and_safety_outlined,
  ),
  WebFeature(
    'Bảo hiểm thất nghiệp',
    '/tools/unemployment',
    Icons.savings_outlined,
  ),
  WebFeature(
    'Kiểm tra lừa đảo tuyển dụng',
    '/tools/scam-check',
    Icons.shield_outlined,
  ),
  WebFeature(
    'Chuyển đổi CV ngân hàng',
    '/tools/bank-cv',
    Icons.description_outlined,
  ),
];

const studentFeatures = <WebFeature>[
  WebFeature('Tìm việc và so khớp CV', '/users?view=jobs', Icons.search),
  WebFeature('CV của tôi và mẫu CV', '/users?view=cv', Icons.article_outlined),
  WebFeature('Hồ sơ tìm việc', '/users?view=profile', Icons.person_outline),
  WebFeature(
    'Phỏng vấn thử với AI',
    '/users/ai-interview',
    Icons.videocam_outlined,
  ),
  WebFeature(
    'Gói tìm việc và thanh toán',
    '/users?view=pricing',
    Icons.payments_outlined,
  ),
  WebFeature(
    'Đơn ứng tuyển',
    '/users?view=applications',
    Icons.assignment_outlined,
  ),
  WebFeature('Lịch phỏng vấn', '/users?view=interviews', Icons.event_outlined),
  WebFeature('Tin nhắn', '/users?view=messages', Icons.chat_bubble_outline),
  WebFeature(
    'Thông báo',
    '/users?view=notifications',
    Icons.notifications_outlined,
  ),
  WebFeature(
    'Lịch rảnh',
    '/users?view=schedule',
    Icons.calendar_month_outlined,
  ),
];

const adminFeatures = <WebFeature>[
  WebFeature('Duyệt tin tuyển dụng', '/admin/jobs', Icons.fact_check_outlined),
  WebFeature(
    'Mẫu CV và CV',
    '/admin/cv-templates',
    Icons.admin_panel_settings_outlined,
  ),
];

class WebPortalHub extends StatelessWidget {
  const WebPortalHub({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tính năng More Job')),
    body: ListView(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Các tính năng web chạy trong ứng dụng. Khi mở tính năng cần tài khoản, hãy đăng nhập trên trang web một lần; phiên đăng nhập web được lưu riêng với phiên Flutter.',
          ),
        ),
        _section(context, 'Công khai và tiện ích', publicFeatures),
        _section(context, 'Sinh viên', studentFeatures),
        _section(context, 'Quản trị', adminFeatures),
      ],
    ),
  );

  Widget _section(
    BuildContext context,
    String title,
    List<WebFeature> features,
  ) => ExpansionTile(
    title: Text(title),
    initiallyExpanded: title == 'Sinh viên',
    children: features
        .map(
          (feature) => ListTile(
            leading: Icon(feature.icon),
            title: Text(feature.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WebFeaturePage(feature: feature),
              ),
            ),
          ),
        )
        .toList(),
  );
}

class WebFeaturePage extends StatefulWidget {
  const WebFeaturePage({super.key, required this.feature});
  final WebFeature feature;

  @override
  State<WebFeaturePage> createState() => _WebFeaturePageState();
}

class _WebFeaturePageState extends State<WebFeaturePage> {
  late final WebViewController controller;
  bool loading = true;
  String? error;
  String? currentUrl;
  late String pendingRoute = widget.feature.path;
  bool loadingRootForRoute = true;

  Uri get origin => Uri.parse(webBaseUrl);

  Future<void> routeFromRoot(String url) async {
    final route = pendingRoute;
    if (route != '/') {
      await controller.runJavaScript(
        'window.history.replaceState({}, "", ${jsonEncode(route)});'
        'window.dispatchEvent(new PopStateEvent("popstate"));',
      );
    }
    if (mounted) {
      setState(() {
        loading = false;
        loadingRootForRoute = false;
        currentUrl = '${origin.origin}$route';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => setState(() {
            loading = true;
            currentUrl = url;
            error = null;
          }),
          onPageFinished: (url) async {
            if (Uri.tryParse(url)?.origin == origin.origin &&
                Uri.tryParse(url)?.path == '/') {
              try {
                await routeFromRoot(url);
              } catch (routeError) {
                if (mounted) {
                  setState(() {
                    loading = false;
                    error = routeError.toString();
                  });
                }
              }
            } else if (mounted) {
              setState(() {
                loading = false;
                currentUrl = url;
              });
            }
          },
          onWebResourceError: (webError) {
            if (webError.isForMainFrame == true) {
              setState(() {
                loading = false;
                error = webError.description;
              });
            }
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            if (uri.origin == origin.origin && uri.path != '/') {
              pendingRoute =
                  '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
              loadingRootForRoute = true;
              Future.microtask(() => controller.loadRequest(origin));
              return NavigationDecision.prevent;
            }
            if (uri.origin == origin.origin &&
                uri.path == '/' &&
                !loadingRootForRoute) {
              pendingRoute = '/';
            }
            if (uri.scheme == 'https' || uri.scheme == 'http') {
              return NavigationDecision.navigate;
            }
            launchUrl(uri, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(origin);

    if (Platform.isAndroid && controller.platform is AndroidWebViewController) {
      final android = controller.platform as AndroidWebViewController;
      android.setOnShowFileSelector((params) async {
        final selected = params.mode == FileSelectorMode.openMultiple
            ? await FilePicker.pickFiles(type: FileType.any)
            : [await FilePicker.pickFile(type: FileType.any)];
        return selected
            .where((file) => file?.path != null)
            .map((file) => Uri.file(file!.path!).toString())
            .toList();
      });
      android.setOnPlatformPermissionRequest((request) async {
        final isTrustedPage =
            Uri.tryParse(currentUrl ?? '')?.host == Uri.parse(webBaseUrl).host;
        if (!isTrustedPage) {
          await request.deny();
          return;
        }
        final permissions = <Permission>[];
        for (final type in request.types) {
          if (type.name == 'camera') permissions.add(Permission.camera);
          if (type.name == 'microphone') permissions.add(Permission.microphone);
        }
        if (permissions.isEmpty) {
          await request.deny();
          return;
        }
        final results = await permissions.request();
        if (results.values.every((status) => status.isGranted)) {
          await request.grant();
        } else {
          await request.deny();
        }
      });
    }
  }

  Future<void> back() async {
    if (await controller.canGoBack()) {
      await controller.goBack();
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> reloadFeature() async {
    final url = await controller.currentUrl();
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri?.origin == origin.origin) {
      pendingRoute = '${uri!.path}${uri.hasQuery ? '?${uri.query}' : ''}';
      loadingRootForRoute = true;
      await controller.loadRequest(origin);
    } else {
      await controller.reload();
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) back();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: back,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(widget.feature.title),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: reloadFeature,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (loading) const LinearProgressIndicator(),
          if (error != null)
            MaterialBanner(
              content: Text('Không tải được trang: $error'),
              actions: [
                TextButton(
                  onPressed: reloadFeature,
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          Expanded(child: WebViewWidget(controller: controller)),
        ],
      ),
    ),
  );
}
