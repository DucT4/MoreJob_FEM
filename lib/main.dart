import 'package:flutter/material.dart';

import 'admin_pages.dart';
import 'ai_interview.dart';
import 'api.dart';
import 'billing_pages.dart';
import 'cv_studio.dart';
import 'student_pages.dart';
import 'theme.dart';
import 'utilities.dart';
import 'web_portal.dart';

void main() => runApp(const MoreJobApp());

final api = MoreJobApi();

class MoreJobApp extends StatefulWidget {
  const MoreJobApp({super.key});
  @override
  State<MoreJobApp> createState() => _MoreJobAppState();
}

class _MoreJobAppState extends State<MoreJobApp> {
  late Future<bool> session = api.restore();
  void changed() => setState(() => session = Future.value(api.user != null));

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MoreJob - Nền tảng Tuyển dụng & AI Career Copilot',
        debugShowCheckedModeBanner: false,
        theme: MoreJobTheme.lightTheme,
        home: FutureBuilder<bool>(
          future: session,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (!snapshot.data!) {
              return AuthPage(onLogin: changed);
            }
            if (api.isAdmin) {
              return AdminPortalPage(
                api: api,
                onLogout: () async {
                  await api.logout();
                  changed();
                },
              );
            }
            return HomePage(onLogout: changed);
          },
        ),
      );
}

void showError(BuildContext context, Object error) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString()),
        backgroundColor: MoreJobColors.danger,
      ),
    );
  }
}

void showSuccess(BuildContext context, String message) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: MoreJobColors.navy,
      ),
    );
  }
}

// =============================================================================
// AUTH & PUBLIC LANDING / RECRUITMENT FEED + UTILITIES BEFORE LOGIN
// =============================================================================
class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.onLogin});
  final VoidCallback onLogin;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  int _publicTab = 0; // 0: Đăng nhập/Đăng ký, 1: Việc làm công khai, 2: 9 Tiện ích
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final _publicKeywordCtrl = TextEditingController();
  bool register = false;
  bool busy = false;
  List<dynamic> _publicJobs = [];
  bool _loadingPublicJobs = false;

  @override
  void initState() {
    super.initState();
    _loadPublicListings();
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    _publicKeywordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPublicListings() async {
    setState(() => _loadingPublicJobs = true);
    try {
      final res = await api.get(
        '/recruitment-listings',
        query: {
          'page': '0',
          'size': '12',
          if (_publicKeywordCtrl.text.trim().isNotEmpty)
            'keyword': _publicKeywordCtrl.text.trim(),
        },
      );
      _publicJobs = MoreJobApi.pageItems(res);
    } catch (_) {
      _publicJobs = [];
    } finally {
      if (mounted) setState(() => _loadingPublicJobs = false);
    }
  }

  Future<void> submit() async {
    if (!email.text.contains('@') ||
        password.text.length < 6 ||
        (register && name.text.trim().isEmpty)) {
      showError(context, 'Kiểm tra họ tên, email và mật khẩu ít nhất 6 ký tự.');
      return;
    }
    setState(() => busy = true);
    try {
      if (register) {
        await api.register(name.text.trim(), email.text.trim(), password.text);
      } else {
        await api.login(email.text.trim(), password.text);
      }
      widget.onLogin();
    } catch (error) {
      if (mounted) showError(context, error);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              MoreJobLogoText(fontSize: 22),
              SizedBox(width: 10),
              StatusPill(label: 'AI Career Copilot', color: MoreJobColors.brand),
            ],
          ),
        ),
        body: IndexedStack(
          index: _publicTab,
          children: [
            _buildLoginCard(context),
            _buildPublicRecruitmentFeed(),
            const UtilitiesHubPage(embedded: true),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _publicTab,
          onDestinationSelected: (idx) => setState(() => _publicTab = idx),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.login_rounded),
              label: 'Tài khoản',
            ),
            NavigationDestination(
              icon: Icon(Icons.work_outline_rounded),
              label: 'Việc làm',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_rounded),
              label: '9 Tiện ích',
            ),
          ],
        ),
      );

  Widget _buildLoginCard(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [MoreJobColors.navy, Color(0xFF1A4F8B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusPill(
                        label: 'Nền tảng việc làm thế hệ mới',
                        color: MoreJobColors.brand,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Kết nối Sinh viên & Doanh nghiệp bằng AI Matching',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Tạo CV chuẩn ATS, phân tích độ khớp JD, luyện phỏng vấn thử AI 1-1 và 9 bộ công cụ sự nghiệp miễn phí.',
                        style: TextStyle(color: Colors.white70, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          register
                              ? 'Đăng ký tài khoản Ứng viên'
                              : 'Đăng nhập vào MoreJob',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: MoreJobColors.ink,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (register) ...[
                          TextField(
                            controller: name,
                            decoration: const InputDecoration(
                              labelText: 'Họ và tên',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email (Ứng viên hoặc Admin)',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: password,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Mật khẩu',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          onPressed: busy ? null : submit,
                          child: Text(
                            busy
                                ? 'Đang xử lý...'
                                : (register ? 'Tạo tài khoản ngay' : 'Đăng nhập'),
                          ),
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => setState(() => register = !register),
                          child: Text(
                            register
                                ? 'Đã có tài khoản? Đăng nhập'
                                : 'Chưa có tài khoản? Đăng ký ứng viên mới',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPublicRecruitmentFeed() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _publicKeywordCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Tìm việc làm theo vị trí, kỹ năng, công ty...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => _loadPublicListings(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _loadPublicListings,
                child: const Text('Tìm'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingPublicJobs
              ? const Center(child: CircularProgressIndicator())
              : _publicJobs.isEmpty
                  ? const Center(
                      child: Text('Đăng nhập để khám phá toàn bộ tin tuyển dụng.'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _publicJobs.length,
                      itemBuilder: (context, index) {
                        final job = _publicJobs[index] as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(14),
                            leading: const CircleAvatar(
                              backgroundColor: MoreJobColors.brandSoft,
                              child: Icon(Icons.work_outline,
                                  color: MoreJobColors.brand),
                            ),
                            title: Text(
                              (job['title'] ?? 'Vị trí tuyển dụng').toString(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${job['companyName'] ?? 'Doanh nghiệp'} • ${job['location'] ?? 'Việt Nam'}',
                            ),
                            trailing: ElevatedButton(
                              onPressed: () => setState(() => _publicTab = 0),
                              child: const Text('Ứng tuyển'),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// =============================================================================
// AUTHENTICATED STUDENT WORKSPACE (HOME PAGE)
// =============================================================================
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onLogout});
  final VoidCallback onLogout;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  bool loading = true;

  // Core data
  List<dynamic> jobs = [];
  List<dynamic> recommended = [];
  List<dynamic> saved = [];
  List<dynamic> cvs = [];
  List<dynamic> applications = [];
  List<dynamic> notifications = [];
  Map<String, dynamic>? profile;
  int unread = 0;

  // Recruitment & CV Match Batch state
  final keyword = TextEditingController();
  final locationCtrl = TextEditingController();
  int? _selectedMatchCvId;
  Map<String, dynamic>? _activeMatchBatch;
  bool _runningMatch = false;

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  @override
  void dispose() {
    keyword.dispose();
    locationCtrl.dispose();
    super.dispose();
  }

  Future<void> loadAll() async {
    setState(() => loading = true);
    try {
      final results = await Future.wait([
        api.get(
          '/recruitment-listings',
          query: {
            'page': '0',
            'size': '20',
            if (keyword.text.trim().isNotEmpty) 'keyword': keyword.text.trim(),
            if (locationCtrl.text.trim().isNotEmpty)
              'location': locationCtrl.text.trim(),
          },
        ).catchError(
          (_) => api.get(
            '/jobs',
            query: {
              'page': '0',
              'size': '20',
              if (keyword.text.trim().isNotEmpty)
                'keyword': keyword.text.trim(),
            },
          ).catchError((_) => []),
        ),
        api.get('/students/me/recommended-jobs').catchError((_) => []),
        api.get('/students/me/saved-jobs').catchError((_) => []),
        api.get('/students/me/cvs').catchError((_) => []),
        api.get('/students/me/applications').catchError((_) => []),
        api.get('/students/me').catchError((_) => null),
        api.get('/notifications/me').catchError((_) => []),
        api.get('/notifications/me/unread-count').catchError((_) => null),
      ]);
      jobs = MoreJobApi.pageItems(results[0]);
      recommended = MoreJobApi.pageItems(results[1]);
      saved = MoreJobApi.pageItems(results[2]);
      cvs = MoreJobApi.pageItems(results[3]);
      applications = MoreJobApi.pageItems(results[4]);
      profile = results[5] is Map<String, dynamic>
          ? results[5] as Map<String, dynamic>
          : null;
      notifications = MoreJobApi.pageItems(results[6]);
      final unreadRaw = results[7];
      unread = unreadRaw is Map
          ? (unreadRaw['unreadCount'] ?? unreadRaw['count'] ?? 0) as int
          : (unreadRaw is int ? unreadRaw : 0);

      if (cvs.isNotEmpty && _selectedMatchCvId == null) {
        final firstId = cvs.first['id'];
        _selectedMatchCvId =
            firstId is int ? firstId : int.tryParse('$firstId');
      }
    } catch (error) {
      if (mounted) showError(context, error);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _runCvMatchBatch() async {
    setState(() => _runningMatch = true);
    try {
      final res = await api.post(
        '/students/me/matches',
        body: {
          if (_selectedMatchCvId != null) 'cvId': _selectedMatchCvId,
          if (keyword.text.trim().isNotEmpty) 'keyword': keyword.text.trim(),
          if (locationCtrl.text.trim().isNotEmpty)
            'location': locationCtrl.text.trim(),
        },
      );
      if (res is Map<String, dynamic>) {
        final batchId = res['id'] ?? res['batchId'];
        if (batchId != null) {
          final detail = await api
              .get('/students/me/matches/$batchId')
              .catchError((_) => res);
          if (detail is Map<String, dynamic>) {
            setState(() => _activeMatchBatch = detail);
          }
        } else {
          setState(() => _activeMatchBatch = res);
        }
        if (mounted) {
          showSuccess(context, 'Đã phân tích CV Match Batch thành công!');
        }
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _runningMatch = false);
    }
  }

  Future<void> _showJobDetailAndApplyModal(Map<String, dynamic> job) async {
    int? chosenCvId = _selectedMatchCvId;
    final coverCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.94,
          minChildSize: 0.5,
          builder: (ctx, scrollCtrl) => ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (job['title'] ?? 'Vị trí tuyển dụng').toString(),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.bookmark_add_outlined,
                        color: MoreJobColors.brand),
                    onPressed: () async {
                      try {
                        await api.post(
                          '/students/me/saved-jobs',
                          body: {'jobId': job['id']},
                        );
                        if (mounted) showSuccess(context, 'Đã lưu việc làm!');
                        await loadAll();
                      } catch (e) {
                        if (mounted) showError(context, e);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () {
                  final compId = job['companyId'] ?? job['employerId'] ?? 1;
                  showCompanyProfileSheet(
                    context,
                    api: api,
                    companyId: compId,
                    fallbackCompanyName: job['companyName']?.toString(),
                  );
                },
                child: Row(
                  children: [
                    const Icon(Icons.business,
                        size: 16, color: MoreJobColors.brand),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${job['companyName'] ?? 'Doanh nghiệp đối tác'} (Xem hồ sơ công ty)',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: MoreJobColors.brand,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusPill(
                    label: (job['location'] ?? 'Việt Nam').toString(),
                    color: MoreJobColors.navy,
                  ),
                  StatusPill(
                    label: (job['jobType'] ?? 'FULL_TIME').toString(),
                    color: MoreJobColors.green,
                  ),
                  if (job['salaryRange'] != null || job['salaryMax'] != null)
                    StatusPill(
                      label:
                          (job['salaryRange'] ?? '${job['salaryMax']} VND')
                              .toString(),
                      color: MoreJobColors.brand,
                    ),
                ],
              ),
              const Divider(height: 24),
              const Text(
                'Mô tả công việc (Job Description)',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                (job['description'] ?? 'Đang cập nhật mô tả chi tiết.')
                    .toString(),
                style: const TextStyle(fontSize: 13.5, height: 1.5),
              ),
              if (job['requirements'] != null) ...[
                const SizedBox(height: 14),
                const Text(
                  'Yêu cầu ứng viên',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  job['requirements'].toString(),
                  style: const TextStyle(fontSize: 13.5, height: 1.5),
                ),
              ],
              const Divider(height: 28),
              const Text(
                'Nộp hồ sơ ứng tuyển ngay',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 10),
              if (cvs.isNotEmpty)
                DropdownButtonFormField<int?>(
                  initialValue: chosenCvId,
                  decoration: const InputDecoration(
                    labelText: 'Chọn CV trong tủ hồ sơ của bạn',
                  ),
                  items: cvs.map((c) {
                    final id = c['id'] is int
                        ? c['id'] as int
                        : int.tryParse('${c['id']}');
                    return DropdownMenuItem<int?>(
                      value: id,
                      child: Text(
                        (c['title'] ?? c['fileName'] ?? 'CV #$id').toString(),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setModalState(() => chosenCvId = v),
                ),
              const SizedBox(height: 10),
              TextField(
                controller: coverCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Thư giới thiệu ngắn gọn (Cover Letter)',
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await api.post(
                      '/students/me/applications',
                      body: {
                        'jobId': job['id'],
                        'cvId': ?chosenCvId,
                        if (coverCtrl.text.trim().isNotEmpty)
                          'coverLetter': coverCtrl.text.trim(),
                      },
                    );
                    if (mounted) {
                      showSuccess(context, 'Đã nộp đơn ứng tuyển thành công!');
                    }
                    await loadAll();
                  } catch (e) {
                    if (mounted) showError(context, e);
                  }
                },
                icon: const Icon(Icons.send_rounded),
                label: const Text('Xác nhận Ứng tuyển'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (ctx, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Trung tâm Thông báo ($unread chưa đọc)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await api.patch('/notifications/me/read-all');
                      await loadAll();
                    } catch (_) {}
                  },
                  child: const Text('Đọc tất cả'),
                ),
              ],
            ),
            const Divider(),
            if (notifications.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Chưa có thông báo mới.')),
              )
            else
              ...notifications.map((n) {
                final item = n as Map<String, dynamic>;
                final isRead = item['read'] == true || item['isRead'] == true;
                return ListTile(
                  leading: Icon(
                    isRead
                        ? Icons.notifications_none
                        : Icons.notifications_active,
                    color: isRead ? MoreJobColors.muted : MoreJobColors.brand,
                  ),
                  title: Text(
                    (item['title'] ?? 'Thông báo hệ thống').toString(),
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.w500 : FontWeight.w800,
                    ),
                  ),
                  subtitle: Text((item['message'] ?? item['content'] ?? '')
                      .toString()),
                  onTap: () async {
                    if (item['id'] != null) {
                      try {
                        await api.patch('/notifications/me/${item['id']}/read');
                        await loadAll();
                      } catch (_) {}
                    }
                  },
                );
              }),
          ],
        ),
      ),
    );
  }

  void _openAuxiliaryPage(String title, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: page,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      // 0: Student Dashboard
      StudentDashboardView(
        profile: profile,
        cvs: cvs,
        applications: applications,
        savedJobs: saved,
        recommendedJobs: recommended,
        interviews: const [],
        onNavigateJobs: () => setState(() => tab = 1),
        onNavigateCvStudio: () => setState(() => tab = 2),
        onNavigateApplications: () => setState(() => tab = 3),
        onNavigateAiInterview: () => _openAuxiliaryPage(
          'Phỏng vấn thử AI 1-1',
          AiInterviewPage(api: api),
        ),
        onSelectJob: _showJobDetailAndApplyModal,
      ),
      // 1: Recruitment Feed + CV Match Batches
      _buildRecruitmentAndMatchTab(),
      // 2: Full CV Studio
      CvStudioPage(
        api: api,
        initialProfile: profile,
        onOpenCheckoutTemplateUnlock: () => _openAuxiliaryPage(
          'Nâng cấp & Mở khóa Pro',
          BillingPricingPage(api: api),
        ),
      ),
      // 3: Applications Kanban + Weekly Schedule
      ApplicationsAndScheduleView(
        api: api,
        applications: applications,
        onRefreshApplications: loadAll,
      ),
      // 4: 9 Career Utilities Hub
      const UtilitiesHubPage(embedded: true),
      // 5: Student Profile + Skills + Onboarding
      StudentProfileEnhancedView(
        api: api,
        initialProfile: profile,
        onProfileUpdated: loadAll,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const MoreJobLogoText(fontSize: 21),
        actions: [
          IconButton(
            tooltip: 'Tin nhắn với Nhà tuyển dụng',
            onPressed: () => _openAuxiliaryPage(
              'Tin nhắn & Hội thoại',
              ConversationsView(api: api),
            ),
            icon: const Icon(Icons.forum_outlined),
          ),
          IconButton(
            tooltip: 'Thông báo',
            onPressed: _openNotificationsSheet,
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          IconButton(
            tooltip: 'Gói Pro & Thanh toán PayOS',
            onPressed: () => _openAuxiliaryPage(
              'Nâng cấp AI Pro & PayOS',
              BillingPricingPage(
                api: api,
                activeMatchBatchId: _activeMatchBatch?['id'] is int
                    ? _activeMatchBatch!['id'] as int
                    : null,
              ),
            ),
            icon: const Icon(
              Icons.workspace_premium,
              color: MoreJobColors.brand,
            ),
          ),
        ],
      ),
      drawer: _buildAppDrawer(),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (idx) => setState(() => tab = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work_rounded),
            label: 'Việc làm',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description_rounded),
            label: 'CV Studio',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_kanban_outlined),
            selectedIcon: Icon(Icons.view_kanban_rounded),
            label: 'Ứng tuyển',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Tiện ích',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Hồ sơ',
          ),
        ],
      ),
    );
  }

  Widget _buildAppDrawer() {
    final fullName = (profile?['fullName'] ?? api.user?['fullName'] ?? 'Ứng viên')
        .toString();
    final emailStr =
        (profile?['email'] ?? api.user?['email'] ?? '').toString();

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: MoreJobColors.navy,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MoreJobLogoText(fontSize: 22, darkBackground: true),
                  const SizedBox(height: 12),
                  Text(
                    fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    emailStr,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.record_voice_over,
                  color: MoreJobColors.brand),
              title: const Text('Phỏng vấn thử AI (AI Mock Interview)'),
              onTap: () {
                Navigator.pop(context);
                _openAuxiliaryPage(
                  'Phỏng vấn thử AI 1-1',
                  AiInterviewPage(api: api),
                );
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.forum_outlined, color: MoreJobColors.navy),
              title: const Text('Tin nhắn với Nhà tuyển dụng'),
              onTap: () {
                Navigator.pop(context);
                _openAuxiliaryPage(
                  'Tin nhắn & Hội thoại',
                  ConversationsView(api: api),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.workspace_premium,
                  color: MoreJobColors.brand),
              title: const Text('Bảng giá AI Pro & Thanh toán PayOS'),
              onTap: () {
                Navigator.pop(context);
                _openAuxiliaryPage(
                  'Bảng giá & Nâng cấp AI Pro',
                  BillingPricingPage(api: api),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.language, color: MoreJobColors.green),
              title: const Text('Cổng Web Đồng bộ (Web Portal Hub)'),
              onTap: () {
                Navigator.pop(context);
                _openAuxiliaryPage(
                  'Cổng Web MoreJob',
                  const WebPortalHub(),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading:
                  const Icon(Icons.logout, color: MoreJobColors.danger),
              title: const Text(
                'Đăng xuất',
                style: TextStyle(color: MoreJobColors.danger),
              ),
              onTap: () async {
                Navigator.pop(context);
                await api.logout();
                widget.onLogout();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecruitmentAndMatchTab() {
    final matchItems = _activeMatchBatch != null &&
            _activeMatchBatch!['matches'] is List
        ? _activeMatchBatch!['matches'] as List
        : (_activeMatchBatch != null && _activeMatchBatch!['items'] is List
            ? _activeMatchBatch!['items'] as List
            : const []);

    return RefreshIndicator(
      onRefresh: loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Search & CV Match Batch Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: MoreJobColors.brand),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tìm việc thông minh & So khớp CV hàng loạt (AI Match)',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: keyword,
                          decoration: const InputDecoration(
                            labelText: 'Vị trí, kỹ năng, công ty',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onSubmitted: (_) => loadAll(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: locationCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Địa điểm',
                          ),
                          onSubmitted: (_) => loadAll(),
                        ),
                      ),
                    ],
                  ),
                  if (cvs.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int?>(
                      initialValue: _selectedMatchCvId,
                      decoration: const InputDecoration(
                        labelText: 'Chọn CV dùng để đối sánh AI Match',
                      ),
                      items: cvs.map((c) {
                        final id = c['id'] is int
                            ? c['id'] as int
                            : int.tryParse('${c['id']}');
                        return DropdownMenuItem<int?>(
                          value: id,
                          child: Text(
                            (c['title'] ?? c['fileName'] ?? 'CV #$id')
                                .toString(),
                          ),
                        );
                      }).toList(),
                      onChanged: (v) =>
                          setState(() => _selectedMatchCvId = v),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: loadAll,
                          icon: const Icon(Icons.filter_list, size: 18),
                          label: const Text('Lọc tin tuyển dụng'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _runningMatch ? null : _runCvMatchBatch,
                          icon: const Icon(Icons.bolt, size: 18),
                          label: Text(
                            _runningMatch
                                ? 'Đang chấm điểm...'
                                : 'Chấm điểm CV Match',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Active CV Match Batch Results Banner
          if (_activeMatchBatch != null) ...[
            const SizedBox(height: 14),
            Card(
              color: MoreJobColors.panel,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Kết quả Phân tích CV Match Batch',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _openAuxiliaryPage(
                            'Mở khóa Top Việc làm Phù hợp',
                            BillingPricingPage(
                              api: api,
                              activeMatchBatchId:
                                  _activeMatchBatch!['id'] is int
                                      ? _activeMatchBatch!['id'] as int
                                      : null,
                            ),
                          ),
                          icon: const Icon(Icons.lock_open, size: 16),
                          label: const Text('Mở khóa Top 3 / Top 5'),
                        ),
                      ],
                    ),
                    if (matchItems.isEmpty)
                      Text(
                        'Đã tạo phiên đối sánh #${_activeMatchBatch!['id'] ?? 'Mới'}. Xem danh sách việc làm gợi ý bên dưới.',
                        style: const TextStyle(fontSize: 13),
                      )
                    else
                      ...matchItems.take(5).map((m) {
                        final item = m as Map<String, dynamic>;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            (item['jobTitle'] ?? item['title'] ?? 'Việc làm')
                                .toString(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                              (item['companyName'] ?? 'Doanh nghiệp').toString()),
                          trailing: StatusPill(
                            label: '${item['matchScore'] ?? item['score'] ?? 88}%',
                            color: MoreJobColors.green,
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Tin tuyển dụng đang mở (${jobs.length})',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ...jobs.map((item) {
            final job = item as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                leading: CircleAvatar(
                  backgroundColor: MoreJobColors.brandSoft,
                  child: const Icon(Icons.work_outline,
                      color: MoreJobColors.brand),
                ),
                title: Text(
                  (job['title'] ?? 'Vị trí tuyển dụng').toString(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      '${job['companyName'] ?? 'Doanh nghiệp'} • ${job['location'] ?? 'Việt Nam'}',
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        StatusPill(
                          label: (job['jobType'] ?? 'FULL_TIME').toString(),
                          color: MoreJobColors.navy,
                        ),
                        if (job['salaryRange'] != null)
                          StatusPill(
                            label: job['salaryRange'].toString(),
                            color: MoreJobColors.green,
                          ),
                      ],
                    ),
                  ],
                ),
                trailing: ElevatedButton(
                  onPressed: () => _showJobDetailAndApplyModal(job),
                  child: const Text('Chi tiết'),
                ),
                onTap: () => _showJobDetailAndApplyModal(job),
              ),
            );
          }),
        ],
      ),
    );
  }
}
