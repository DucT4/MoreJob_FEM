import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'api.dart';
import 'theme.dart';

// =============================================================================
// 1. STUDENT DASHBOARD VIEW
// =============================================================================
class StudentDashboardView extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final List<dynamic> cvs;
  final List<dynamic> applications;
  final List<dynamic> savedJobs;
  final List<dynamic> recommendedJobs;
  final List<dynamic> interviews;
  final VoidCallback onNavigateJobs;
  final VoidCallback onNavigateCvStudio;
  final VoidCallback onNavigateApplications;
  final VoidCallback onNavigateAiInterview;
  final void Function(Map<String, dynamic> job) onSelectJob;

  const StudentDashboardView({
    super.key,
    required this.profile,
    required this.cvs,
    required this.applications,
    required this.savedJobs,
    required this.recommendedJobs,
    required this.interviews,
    required this.onNavigateJobs,
    required this.onNavigateCvStudio,
    required this.onNavigateApplications,
    required this.onNavigateAiInterview,
    required this.onSelectJob,
  });

  @override
  Widget build(BuildContext context) {
    final name = (profile?['fullName'] ?? 'Ứng viên MoreJob').toString();
    final major =
        (profile?['major'] ?? 'Sinh viên & Người tìm việc').toString();
    final uni = (profile?['university'] ?? '').toString();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Hero Welcome Card matching web StudentDashboard
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [MoreJobColors.navy, Color(0xFF1A4F8B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: MoreJobColors.brand,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'M',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Xin chào, $name 👋',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          uni.isNotEmpty ? '$major • $uni' : major,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: onNavigateJobs,
                    icon: const Icon(Icons.bolt, size: 16),
                    label: const Text('So khớp CV & Tìm việc'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                    ),
                    onPressed: onNavigateCvStudio,
                    icon: const Icon(Icons.description_outlined, size: 16),
                    label: const Text('CV Studio'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                    ),
                    onPressed: onNavigateAiInterview,
                    icon: const Icon(Icons.record_voice_over, size: 16),
                    label: const Text('Phỏng vấn AI'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 4 KPI Cards
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.65,
          children: [
            _buildKpiTile(
              label: 'Đơn ứng tuyển',
              value: '${applications.length}',
              icon: Icons.send_rounded,
              color: MoreJobColors.brand,
              onTap: onNavigateApplications,
            ),
            _buildKpiTile(
              label: 'CV trong tủ',
              value: '${cvs.length}',
              icon: Icons.description_rounded,
              color: MoreJobColors.navy,
              onTap: onNavigateCvStudio,
            ),
            _buildKpiTile(
              label: 'Việc đã lưu',
              value: '${savedJobs.length}',
              icon: Icons.bookmark_rounded,
              color: MoreJobColors.green,
              onTap: onNavigateJobs,
            ),
            _buildKpiTile(
              label: 'Lịch phỏng vấn',
              value: '${interviews.length}',
              icon: Icons.event_available_rounded,
              color: const Color(0xFF8B5CF6),
              onTap: onNavigateApplications,
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 30-day Activity Mini Chart
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tần suất ứng tuyển & Tương tác hồ sơ',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    StatusPill(
                      label: '30 ngày qua',
                      color: MoreJobColors.navy,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 104,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (idx) {
                      final heights = [26.0, 42.0, 35.0, 58.0, 48.0, 72.0, 64.0];
                      final labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
                      return Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              width: 20,
                              height: heights[idx],
                              decoration: BoxDecoration(
                                color: idx >= 5
                                    ? MoreJobColors.brand
                                    : MoreJobColors.navy.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              labels[idx],
                              style: const TextStyle(
                                fontSize: 11,
                                color: MoreJobColors.muted,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Recommended Jobs Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Việc làm AI gợi ý phù hợp nhất',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            TextButton(
              onPressed: onNavigateJobs,
              child: const Text('Xem tất cả'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (recommendedJobs.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Hãy cập nhật kỹ năng và tải CV để nhận gợi ý việc làm chính xác hơn.',
                style: TextStyle(color: MoreJobColors.muted),
              ),
            ),
          )
        else
          ...recommendedJobs.take(5).map((item) {
            final job = item as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
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
                subtitle: Text(
                  '${job['companyName'] ?? 'Doanh nghiệp'} • ${job['location'] ?? 'Việt Nam'}',
                ),
                trailing: const StatusPill(
                  label: 'AI Match',
                  color: MoreJobColors.green,
                ),
                onTap: () => onSelectJob(job),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildKpiTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MoreJobColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: MoreJobColors.ink,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: MoreJobColors.muted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 2. COMPANY PROFILE SHEET / MODAL
// =============================================================================
Future<void> showCompanyProfileSheet(
  BuildContext context, {
  required MoreJobApi api,
  required dynamic companyId,
  String? fallbackCompanyName,
}) async {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _CompanyProfileSheetContent(
      api: api,
      companyId: companyId,
      fallbackCompanyName: fallbackCompanyName,
    ),
  );
}

class _CompanyProfileSheetContent extends StatefulWidget {
  final MoreJobApi api;
  final dynamic companyId;
  final String? fallbackCompanyName;

  const _CompanyProfileSheetContent({
    required this.api,
    required this.companyId,
    this.fallbackCompanyName,
  });

  @override
  State<_CompanyProfileSheetContent> createState() =>
      _CompanyProfileSheetContentState();
}

class _CompanyProfileSheetContentState
    extends State<_CompanyProfileSheetContent> {
  bool _loading = true;
  bool _following = false;
  Map<String, dynamic>? _company;
  List<dynamic> _companyJobs = [];

  @override
  void initState() {
    super.initState();
    _loadCompany();
  }

  Future<void> _loadCompany() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.api
            .get('/companies/${widget.companyId}/profile')
            .catchError((_) => null),
        widget.api
            .get('/companies/${widget.companyId}/jobs')
            .catchError((_) => []),
      ]);
      if (results[0] is Map<String, dynamic>) {
        _company = results[0] as Map<String, dynamic>;
        _following = _company!['following'] == true ||
            _company!['isFollowing'] == true;
      }
      _companyJobs = MoreJobApi.pageItems(results[1]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    try {
      if (_following) {
        await widget.api.delete('/companies/${widget.companyId}/follow');
        setState(() => _following = false);
      } else {
        await widget.api.post('/companies/${widget.companyId}/follow');
        setState(() => _following = true);
      }
    } catch (_) {
      setState(() => _following = !_following);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (_company?['companyName'] ??
            _company?['name'] ??
            widget.fallbackCompanyName ??
            'Doanh nghiệp đối tác')
        .toString();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      builder: (context, scrollCtrl) {
        if (_loading) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: MoreJobColors.panel,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'C',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: MoreJobColors.navy,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_company?['industry'] ?? 'Đa ngành'} • Quy mô: ${_company?['companySize'] ?? '100-500 nhân sự'}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: MoreJobColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _following ? MoreJobColors.navy : MoreJobColors.brand,
                  ),
                  onPressed: _toggleFollow,
                  icon: Icon(
                    _following ? Icons.check : Icons.add,
                    size: 16,
                  ),
                  label: Text(_following ? 'Đang theo dõi' : 'Theo dõi'),
                ),
              ],
            ),
            const Divider(height: 28),
            const Text(
              'Giới thiệu doanh nghiệp',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              (_company?['description'] ??
                      _company?['overview'] ??
                      'Doanh nghiệp đối tác tuyển dụng chính thức trên hệ sinh thái MoreJob.')
                  .toString(),
              style: const TextStyle(fontSize: 13.5, height: 1.5),
            ),
            if (_company?['website'] != null) ...[
              const SizedBox(height: 10),
              Text(
                'Website: ${_company!['website']}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: MoreJobColors.brand,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              'Vị trí đang tuyển dụng (${_companyJobs.length})',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 8),
            if (_companyJobs.isEmpty)
              const Text(
                'Hiện chưa có thêm vị trí mở công khai.',
                style: TextStyle(color: MoreJobColors.muted),
              )
            else
              ..._companyJobs.map((j) {
                final job = j as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(
                      (job['title'] ?? 'Vị trí tuyển dụng').toString(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${job['location'] ?? 'Việt Nam'} • ${job['jobType'] ?? 'FULL_TIME'}',
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

// =============================================================================
// 3. APPLICATIONS KANBAN & INTERVIEWS + WEEKLY AVAILABILITY SCHEDULE
// =============================================================================
class ApplicationsAndScheduleView extends StatefulWidget {
  final MoreJobApi api;
  final List<dynamic> applications;
  final VoidCallback onRefreshApplications;

  const ApplicationsAndScheduleView({
    super.key,
    required this.api,
    required this.applications,
    required this.onRefreshApplications,
  });

  @override
  State<ApplicationsAndScheduleView> createState() =>
      _ApplicationsAndScheduleViewState();
}

class _ApplicationsAndScheduleViewState
    extends State<ApplicationsAndScheduleView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _stageFilter = 'ALL';
  List<Map<String, String>> _availabilities = [];
  bool _loadingSchedule = false;

  String _selectedDay = 'MONDAY';
  String _startTime = '09:00';
  String _endTime = '11:30';

  static const _daysOfWeek = [
    {'code': 'MONDAY', 'label': 'Thứ Hai'},
    {'code': 'TUESDAY', 'label': 'Thứ Ba'},
    {'code': 'WEDNESDAY', 'label': 'Thứ Tư'},
    {'code': 'THURSDAY', 'label': 'Thứ Năm'},
    {'code': 'FRIDAY', 'label': 'Thứ Sáu'},
    {'code': 'SATURDAY', 'label': 'Thứ Bảy'},
    {'code': 'SUNDAY', 'label': 'Chủ Nhật'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAvailability();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailability() async {
    setState(() => _loadingSchedule = true);
    try {
      final res = await widget.api.get('/students/me/availability');
      final list = res is Map && res['availabilities'] is List
          ? res['availabilities'] as List
          : MoreJobApi.pageItems(res);
      _availabilities = list.map((item) {
        final m = item as Map;
        return {
          'dayOfWeek': (m['dayOfWeek'] ?? 'MONDAY').toString(),
          'startTime': (m['startTime'] ?? '09:00').toString(),
          'endTime': (m['endTime'] ?? '11:30').toString(),
        };
      }).toList();
    } catch (_) {
      if (_availabilities.isEmpty) {
        _availabilities = [
          {'dayOfWeek': 'MONDAY', 'startTime': '09:00', 'endTime': '11:30'},
          {'dayOfWeek': 'WEDNESDAY', 'startTime': '14:00', 'endTime': '17:00'},
        ];
      }
    } finally {
      if (mounted) setState(() => _loadingSchedule = false);
    }
  }

  Future<void> _saveAvailability() async {
    try {
      await widget.api.put(
        '/students/me/availability',
        body: {'availabilities': _availabilities},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu lịch rảnh phỏng vấn hàng tuần!'),
          backgroundColor: MoreJobColors.navy,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã lưu lịch cục bộ ($e)'),
          backgroundColor: MoreJobColors.navy,
        ),
      );
    }
  }

  bool _matchesStage(Map<String, dynamic> app) {
    if (_stageFilter == 'ALL') return true;
    final st = (app['status'] ?? 'APPLIED').toString().toUpperCase();
    if (_stageFilter == 'APPLIED') {
      return st == 'APPLIED' || st == 'PENDING' || st == 'SUBMITTED';
    }
    if (_stageFilter == 'REVIEWING') {
      return st == 'VIEWED' || st == 'REVIEWING' || st == 'SHORTLISTED';
    }
    if (_stageFilter == 'INTERVIEW') {
      return st == 'INTERVIEW' || st == 'ACCEPTED' || st == 'HIRED' || st == 'OFFERED';
    }
    if (_stageFilter == 'CLOSED') {
      return st == 'REJECTED' || st == 'CANCELLED' || st == 'WITHDRAWN';
    }
    return true;
  }

  Future<void> _openApplicationDetail(Map<String, dynamic> app) async {
    final appId = app['id'];
    List<dynamic> appInterviews = [];
    if (appId != null) {
      try {
        final res = await widget.api
            .get('/students/me/applications/$appId/interviews');
        appInterviews = MoreJobApi.pageItems(res);
      } catch (_) {}
    }
    if (!mounted) return;
    final reasonCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (app['jobTitle'] ??
                              app['job']?['title'] ??
                              'Đơn ứng tuyển #$appId')
                          .toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  StatusPill(
                    label: (app['status'] ?? 'APPLIED').toString(),
                    color: MoreJobColors.brand,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Doanh nghiệp: ${app['companyName'] ?? app['job']?['companyName'] ?? 'N/A'}',
                style: const TextStyle(color: MoreJobColors.muted),
              ),
              if ((app['coverLetter'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Thư giới thiệu (Cover Letter):',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(app['coverLetter'].toString()),
              ],
              const Divider(height: 24),
              Text(
                'Lịch phỏng vấn của đơn này (${appInterviews.length})',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (appInterviews.isEmpty)
                const Text(
                  'Chưa có lịch phỏng vấn được ấn định cho đơn này.',
                  style: TextStyle(color: MoreJobColors.muted, fontSize: 13),
                )
              else
                ...appInterviews.map((iv) {
                  final m = iv as Map<String, dynamic>;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.videocam_outlined,
                        color: MoreJobColors.brand),
                    title: Text(
                      (m['scheduledAt'] ?? m['interviewTime'] ?? 'Lịch hẹn')
                          .toString(),
                    ),
                    subtitle: Text(
                      'Hình thức: ${m['type'] ?? m['format'] ?? 'Online'} • ${m['meetingLink'] ?? m['location'] ?? ''}',
                    ),
                  );
                }),
              if (app['status'] != 'CANCELLED' &&
                  app['status'] != 'WITHDRAWN' &&
                  appId != null) ...[
                const Divider(height: 24),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Lý do rút đơn ứng tuyển (Tùy chọn)',
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        await widget.api.patch(
                          '/students/me/applications/$appId/cancel',
                          body: {
                            if (reasonCtrl.text.trim().isNotEmpty)
                              'reason': reasonCtrl.text.trim(),
                          },
                        );
                        widget.onRefreshApplications();
                      } catch (_) {}
                    },
                    icon: const Icon(Icons.cancel_outlined,
                        color: MoreJobColors.danger),
                    label: const Text(
                      'Rút hồ sơ ứng tuyển',
                      style: TextStyle(color: MoreJobColors.danger),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.applications
        .where((e) => _matchesStage(e as Map<String, dynamic>))
        .toList();

    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: MoreJobColors.brand,
            unselectedLabelColor: MoreJobColors.muted,
            indicatorColor: MoreJobColors.brand,
            tabs: [
              Tab(text: 'Kanban Ứng tuyển (${widget.applications.length})'),
              const Tab(text: 'Lịch phỏng vấn & Khung giờ rảnh'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Kanban Applications
              Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        _buildStageChip('ALL', 'Tất cả'),
                        _buildStageChip('APPLIED', 'Đã nộp'),
                        _buildStageChip('REVIEWING', 'NTD đang xem'),
                        _buildStageChip('INTERVIEW', 'Phỏng vấn / Offer'),
                        _buildStageChip('CLOSED', 'Đã đóng / Rút'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text('Không có đơn ứng tuyển ở trạng thái này.'),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final app =
                                  filtered[index] as Map<String, dynamic>;
                              final status =
                                  (app['status'] ?? 'APPLIED').toString();
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(14),
                                  leading: const CircleAvatar(
                                    backgroundColor: MoreJobColors.panel,
                                    child: Icon(Icons.assignment_turned_in,
                                        color: MoreJobColors.navy),
                                  ),
                                  title: Text(
                                    (app['jobTitle'] ??
                                            app['job']?['title'] ??
                                            'Đơn #${app['id']}')
                                        .toString(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700),
                                  ),
                                  subtitle: Text(
                                    '${app['companyName'] ?? app['job']?['companyName'] ?? 'Doanh nghiệp'} • Nộp: ${app['appliedAt'] ?? app['createdAt'] ?? 'Mới nộp'}',
                                  ),
                                  trailing: StatusPill(
                                    label: status,
                                    color: status == 'CANCELLED' ||
                                            status == 'REJECTED'
                                        ? MoreJobColors.danger
                                        : MoreJobColors.brand,
                                  ),
                                  onTap: () => _openApplicationDetail(app),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
              // Tab 2: Weekly Availability Schedule
              _loadingSchedule
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Đăng ký khung giờ rảnh phỏng vấn hàng tuần',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Nhà tuyển dụng sẽ dựa trên lịch rảnh này để đặt lịch phỏng vấn phù hợp với lịch học của bạn.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: MoreJobColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedDay,
                                  decoration: const InputDecoration(
                                    labelText: 'Thứ trong tuần',
                                  ),
                                  items: _daysOfWeek
                                      .map(
                                        (d) => DropdownMenuItem(
                                          value: d['code'],
                                          child: Text(d['label']!),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => setState(
                                      () => _selectedDay = v ?? 'MONDAY'),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _startTime,
                                        decoration: const InputDecoration(
                                            labelText: 'Từ giờ'),
                                        items: const [
                                          DropdownMenuItem(
                                              value: '08:00',
                                              child: Text('08:00')),
                                          DropdownMenuItem(
                                              value: '09:00',
                                              child: Text('09:00')),
                                          DropdownMenuItem(
                                              value: '13:30',
                                              child: Text('13:30')),
                                          DropdownMenuItem(
                                              value: '14:00',
                                              child: Text('14:00')),
                                          DropdownMenuItem(
                                              value: '18:30',
                                              child: Text('18:30')),
                                        ],
                                        onChanged: (v) => setState(
                                            () => _startTime = v ?? '09:00'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _endTime,
                                        decoration: const InputDecoration(
                                            labelText: 'Đến giờ'),
                                        items: const [
                                          DropdownMenuItem(
                                              value: '11:30',
                                              child: Text('11:30')),
                                          DropdownMenuItem(
                                              value: '12:00',
                                              child: Text('12:00')),
                                          DropdownMenuItem(
                                              value: '17:00',
                                              child: Text('17:00')),
                                          DropdownMenuItem(
                                              value: '18:00',
                                              child: Text('18:00')),
                                          DropdownMenuItem(
                                              value: '21:00',
                                              child: Text('21:00')),
                                        ],
                                        onChanged: (v) => setState(
                                            () => _endTime = v ?? '11:30'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _availabilities.add({
                                            'dayOfWeek': _selectedDay,
                                            'startTime': _startTime,
                                            'endTime': _endTime,
                                          });
                                        });
                                      },
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text('Thêm ca rảnh'),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _saveAvailability,
                                        icon: const Icon(Icons.save, size: 16),
                                        label: const Text('Lưu lịch rảnh'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._availabilities.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final slot = entry.value;
                          final dayLabel = _daysOfWeek.firstWhere(
                            (d) => d['code'] == slot['dayOfWeek'],
                            orElse: () => {'label': slot['dayOfWeek'] ?? ''},
                          )['label'];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.access_time_filled,
                                  color: MoreJobColors.brand),
                              title: Text(
                                '$dayLabel: ${slot['startTime']} - ${slot['endTime']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: MoreJobColors.danger),
                                onPressed: () {
                                  setState(() => _availabilities.removeAt(idx));
                                },
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStageChip(String code, String label) {
    final selected = _stageFilter == code;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: MoreJobColors.brandSoft,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: selected ? MoreJobColors.brandStrong : MoreJobColors.ink,
        ),
        onSelected: (_) => setState(() => _stageFilter = code),
      ),
    );
  }
}

// =============================================================================
// 4. MESSAGES / CONVERSATIONS VIEW (WITH QUICK REPLIES & ATTACHMENTS)
// =============================================================================
class ConversationsView extends StatefulWidget {
  final MoreJobApi api;

  const ConversationsView({super.key, required this.api});

  @override
  State<ConversationsView> createState() => _ConversationsViewState();
}

class _ConversationsViewState extends State<ConversationsView> {
  bool _loading = true;
  bool _sending = false;
  List<dynamic> _conversations = [];
  Map<String, dynamic>? _activeConversation;
  List<dynamic> _messages = [];
  final _msgCtrl = TextEditingController();

  static const _quickReplies = [
    'Em xin cảm ơn Quý công ty đã phản hồi hồ sơ của em ạ.',
    'Em xác nhận có thể tham gia phỏng vấn theo khung giờ trên ạ.',
    'Em xin gửi đính kèm bản CV PDF cập nhật mới nhất ạ.',
  ];

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() => _loading = true);
    try {
      final res = await widget.api.get('/conversations/me');
      _conversations = MoreJobApi.pageItems(res);
      if (_conversations.isNotEmpty && _activeConversation == null) {
        await _selectConversation(
            _conversations.first as Map<String, dynamic>);
      }
    } catch (_) {
      _conversations = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectConversation(Map<String, dynamic> conv) async {
    setState(() => _activeConversation = conv);
    final id = conv['id'];
    if (id == null) return;
    try {
      final res = await widget.api.get('/conversations/$id/messages');
      setState(() => _messages = MoreJobApi.pageItems(res));
      await widget.api.patch('/conversations/$id/read');
    } catch (_) {}
  }

  Future<void> _sendMessage([String? preset]) async {
    final text = (preset ?? _msgCtrl.text).trim();
    if (text.isEmpty || _activeConversation == null) return;
    if (preset == null) _msgCtrl.clear();

    setState(() => _sending = true);
    final id = _activeConversation!['id'];
    try {
      await widget.api.post(
        '/conversations/$id/messages',
        body: {'content': text, 'message': text},
      );
      await _selectConversation(_activeConversation!);
    } catch (e) {
      setState(() {
        _messages.add({
          'content': text,
          'senderRole': 'STUDENT',
          'createdAt': 'Vừa xong',
        });
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendAttachment() async {
    if (_activeConversation == null) return;
    final file = await FilePicker.pickFile();
    if (file == null) return;

    setState(() => _sending = true);
    try {
      final rawId = _activeConversation!['id'];
      final convId = rawId is int ? rawId : int.tryParse('$rawId') ?? 0;
      await widget.api.sendConversationAttachment(
        conversationId: convId,
        clientMessageId: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        file: file,
      );
      _msgCtrl.clear();
      await _selectConversation(_activeConversation!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi gửi tệp đính kèm: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.forum_outlined,
                  size: 56, color: MoreJobColors.muted),
              const SizedBox(height: 12),
              const Text(
                'Chưa có hội thoại với Nhà tuyển dụng',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'Khi nhà tuyển dụng liên hệ hoặc mời phỏng vấn, tin nhắn sẽ xuất hiện tại đây.',
                textAlign: TextAlign.center,
                style: TextStyle(color: MoreJobColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Horizontal conversation selector
        Container(
          height: 68,
          color: Colors.white,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            itemCount: _conversations.length,
            itemBuilder: (context, index) {
              final c = _conversations[index] as Map<String, dynamic>;
              final isSelected = _activeConversation?['id'] == c['id'];
              final title = (c['employerName'] ??
                      c['companyName'] ??
                      c['title'] ??
                      'Hội thoại #${c['id']}')
                  .toString();
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: isSelected,
                  selectedColor: MoreJobColors.brandSoft,
                  label: Text(title),
                  onSelected: (_) => _selectConversation(c),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final m = _messages[index] as Map<String, dynamic>;
              final isMe = m['senderRole'] == 'STUDENT' || m['isMine'] == true;
              return Align(
                alignment:
                    isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(maxWidth: 300),
                  decoration: BoxDecoration(
                    color: isMe ? MoreJobColors.brand : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: isMe
                        ? null
                        : Border.all(color: MoreJobColors.border),
                  ),
                  child: Text(
                    (m['content'] ?? m['message'] ?? '').toString(),
                    style: TextStyle(
                      color: isMe ? Colors.white : MoreJobColors.ink,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Quick replies
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: _quickReplies
                .map(
                  (q) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(q, style: const TextStyle(fontSize: 11.5)),
                      onPressed: () => _sendMessage(q),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: _sending ? null : _sendAttachment,
                icon: const Icon(Icons.attach_file, color: MoreJobColors.navy),
              ),
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Nhập tin nhắn gửi Nhà tuyển dụng...',
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: MoreJobColors.brand,
                ),
                onPressed: _sending ? null : () => _sendMessage(),
                icon: const Icon(Icons.send, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 5. STUDENT PROFILE + AVATAR UPLOAD + SKILLS + 4-STEP ONBOARDING WIZARD
// =============================================================================
class StudentProfileEnhancedView extends StatefulWidget {
  final MoreJobApi api;
  final Map<String, dynamic>? initialProfile;
  final VoidCallback onProfileUpdated;

  const StudentProfileEnhancedView({
    super.key,
    required this.api,
    this.initialProfile,
    required this.onProfileUpdated,
  });

  @override
  State<StudentProfileEnhancedView> createState() =>
      _StudentProfileEnhancedViewState();
}

class _StudentProfileEnhancedViewState
    extends State<StudentProfileEnhancedView> {
  bool _busy = false;
  late TextEditingController _fullNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _uniCtrl;
  late TextEditingController _majorCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _gpaCtrl;
  late TextEditingController _gradYearCtrl;
  late TextEditingController _linkedinCtrl;
  late TextEditingController _githubCtrl;
  late TextEditingController _portfolioCtrl;
  late TextEditingController _locationsCtrl;
  bool _openToWork = true;
  String? _avatarUrl;

  List<Map<String, String>> _skills = [];
  final _newSkillCtrl = TextEditingController();
  String _newSkillLevel = 'ADVANCED';

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile ?? {};
    _fullNameCtrl =
        TextEditingController(text: (p['fullName'] ?? '').toString());
    _phoneCtrl = TextEditingController(text: (p['phone'] ?? '').toString());
    _uniCtrl = TextEditingController(text: (p['university'] ?? '').toString());
    _majorCtrl = TextEditingController(text: (p['major'] ?? '').toString());
    _bioCtrl = TextEditingController(text: (p['bio'] ?? '').toString());
    _gpaCtrl = TextEditingController(text: (p['gpa'] ?? '').toString());
    _gradYearCtrl =
        TextEditingController(text: (p['graduationYear'] ?? '').toString());
    _linkedinCtrl =
        TextEditingController(text: (p['linkedinUrl'] ?? '').toString());
    _githubCtrl =
        TextEditingController(text: (p['githubUrl'] ?? '').toString());
    _portfolioCtrl =
        TextEditingController(text: (p['portfolioUrl'] ?? '').toString());
    _locationsCtrl =
        TextEditingController(text: (p['preferredLocations'] ?? '').toString());
    _openToWork = p['openToWork'] != false;
    _avatarUrl = p['avatarUrl']?.toString();
    _loadSkills();
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _uniCtrl.dispose();
    _majorCtrl.dispose();
    _bioCtrl.dispose();
    _gpaCtrl.dispose();
    _gradYearCtrl.dispose();
    _linkedinCtrl.dispose();
    _githubCtrl.dispose();
    _portfolioCtrl.dispose();
    _locationsCtrl.dispose();
    _newSkillCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSkills() async {
    try {
      final res = await widget.api.get('/students/me/skills');
      final items = res is Map && res['skills'] is List
          ? res['skills'] as List
          : MoreJobApi.pageItems(res);
      if (mounted) {
        setState(() {
          _skills = items.map((s) {
            if (s is Map) {
              return {
                'name': (s['name'] ?? s['skillName'] ?? '').toString(),
                'level':
                    (s['level'] ?? s['proficiency'] ?? 'ADVANCED').toString(),
              };
            }
            return {'name': s.toString(), 'level': 'ADVANCED'};
          }).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _uploadAvatar() async {
    final file = await FilePicker.pickFile(
      type: FileType.image,
    );
    if (file == null) return;

    setState(() => _busy = true);
    try {
      final uploadedUrl = await widget.api.uploadAvatar(file);
      setState(() {
        _avatarUrl = uploadedUrl;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tải ảnh đại diện mới!')),
        );
      }
      widget.onProfileUpdated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải ảnh: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveProfileAndSkills() async {
    setState(() => _busy = true);
    try {
      await widget.api.put(
        '/students/me',
        body: {
          'fullName': _fullNameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'university': _uniCtrl.text.trim(),
          'major': _majorCtrl.text.trim(),
          'bio': _bioCtrl.text.trim(),
          if (double.tryParse(_gpaCtrl.text.trim()) != null)
            'gpa': double.parse(_gpaCtrl.text.trim()),
          if (int.tryParse(_gradYearCtrl.text.trim()) != null)
            'graduationYear': int.parse(_gradYearCtrl.text.trim()),
          'linkedinUrl': _linkedinCtrl.text.trim(),
          'githubUrl': _githubCtrl.text.trim(),
          'portfolioUrl': _portfolioCtrl.text.trim(),
          'preferredLocations': _locationsCtrl.text.trim(),
          'openToWork': _openToWork,
          if (_avatarUrl != null) 'avatarUrl': _avatarUrl,
        },
      );
      try {
        await widget.api.put(
          '/students/me/skills',
          body: {'skills': _skills},
        );
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật Hồ sơ & Kỹ năng thành công!'),
            backgroundColor: MoreJobColors.navy,
          ),
        );
      }
      widget.onProfileUpdated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi lưu hồ sơ: $e'),
            backgroundColor: MoreJobColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openOnboardingWizard() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _OnboardingWizardSheet(
        api: widget.api,
        initialMajor: _majorCtrl.text,
        initialUni: _uniCtrl.text,
        initialLocations: _locationsCtrl.text,
        onCompleted: () {
          widget.onProfileUpdated();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: _busy ? null : _uploadAvatar,
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: MoreJobColors.brandSoft,
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          color: MoreJobColors.brand,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _fullNameCtrl.text.isEmpty
                                ? 'Hồ sơ Ứng viên MoreJob'
                                : _fullNameCtrl.text,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Nhấn vào biểu tượng máy ảnh để tải Avatar mới',
                            style: TextStyle(
                              fontSize: 12,
                              color: MoreJobColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openOnboardingWizard,
                      icon: const Icon(Icons.auto_fix_high, size: 16),
                      label: const Text('Onboarding 4 bước'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _openToWork,
                  activeThumbColor: MoreJobColors.green,
                  title: const Text(
                    'Trạng thái Open To Work (Cho phép NTD săn đón)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                  onChanged: (v) => setState(() => _openToWork = v),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thông tin cá nhân & Học vấn',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _fullNameCtrl,
                  decoration: const InputDecoration(labelText: 'Họ và tên'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Số điện thoại'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _uniCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Trường Đại học / Cao đẳng'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _majorCtrl,
                  decoration: const InputDecoration(labelText: 'Chuyên ngành'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _gpaCtrl,
                        decoration:
                            const InputDecoration(labelText: 'GPA (Hệ 4.0)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _gradYearCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Năm tốt nghiệp'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _locationsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Khu vực làm việc mong muốn (TP.HCM, Hà Nội...)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _bioCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Giới thiệu bản thân & Định hướng nghề nghiệp',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _linkedinCtrl,
                  decoration: const InputDecoration(labelText: 'LinkedIn URL'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _githubCtrl,
                  decoration: const InputDecoration(labelText: 'GitHub URL'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _portfolioCtrl,
                  decoration: const InputDecoration(labelText: 'Portfolio URL'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Skills Management Card (/students/me/skills)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hồ sơ Kỹ năng chuyên môn (/students/me/skills)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _newSkillCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Thêm kỹ năng (VD: Flutter, Spring Boot)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _newSkillLevel,
                        decoration: const InputDecoration(labelText: 'Mức độ'),
                        items: const [
                          DropdownMenuItem(
                              value: 'BEGINNER', child: Text('Cơ bản')),
                          DropdownMenuItem(
                              value: 'INTERMEDIATE', child: Text('Khá')),
                          DropdownMenuItem(
                              value: 'ADVANCED', child: Text('Thành thạo')),
                        ],
                        onChanged: (v) =>
                            setState(() => _newSkillLevel = v ?? 'ADVANCED'),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        final name = _newSkillCtrl.text.trim();
                        if (name.isEmpty) return;
                        setState(() {
                          _skills.add({'name': name, 'level': _newSkillLevel});
                          _newSkillCtrl.clear();
                        });
                      },
                      icon: const Icon(Icons.add_circle,
                          color: MoreJobColors.brand),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _skills.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final s = entry.value;
                    return Chip(
                      label: Text('${s['name']} (${s['level']})'),
                      onDeleted: () => setState(() => _skills.removeAt(idx)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _saveProfileAndSkills,
            icon: const Icon(Icons.save),
            label: Text(_busy ? 'Đang lưu...' : 'Lưu toàn bộ Hồ sơ & Kỹ năng'),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}

class _OnboardingWizardSheet extends StatefulWidget {
  final MoreJobApi api;
  final String initialMajor;
  final String initialUni;
  final String initialLocations;
  final VoidCallback onCompleted;

  const _OnboardingWizardSheet({
    required this.api,
    required this.initialMajor,
    required this.initialUni,
    required this.initialLocations,
    required this.onCompleted,
  });

  @override
  State<_OnboardingWizardSheet> createState() => _OnboardingWizardSheetState();
}

class _OnboardingWizardSheetState extends State<_OnboardingWizardSheet> {
  int _step = 0;
  late TextEditingController _roleCtrl;
  late TextEditingController _uniCtrl;
  late TextEditingController _locCtrl;
  String _jobType = 'FULL_TIME';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _roleCtrl = TextEditingController(
      text: widget.initialMajor.isEmpty
          ? 'Fresher Software Engineer'
          : widget.initialMajor,
    );
    _uniCtrl = TextEditingController(text: widget.initialUni);
    _locCtrl = TextEditingController(
      text: widget.initialLocations.isEmpty ? 'TP.HCM' : widget.initialLocations,
    );
  }

  @override
  void dispose() {
    _roleCtrl.dispose();
    _uniCtrl.dispose();
    _locCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitOnboarding() async {
    setState(() => _submitting = true);
    try {
      await widget.api.post(
        '/student-profiles/onboarding',
        body: {
          'major': _roleCtrl.text.trim(),
          'university': _uniCtrl.text.trim(),
          'preferredLocations': _locCtrl.text.trim(),
          'preferredJobTypes': _jobType,
          'openToWork': true,
        },
      );
      widget.onCompleted();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      widget.onCompleted();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Thiết lập Hồ sơ Nhanh (4 Bước)',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              StatusPill(
                label: 'Bước ${_step + 1}/4',
                color: MoreJobColors.brand,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_step == 0)
            TextField(
              controller: _roleCtrl,
              decoration: const InputDecoration(
                labelText: 'Bước 1: Chuyên ngành / Vị trí mục tiêu của bạn',
              ),
            )
          else if (_step == 1)
            TextField(
              controller: _uniCtrl,
              decoration: const InputDecoration(
                labelText: 'Bước 2: Trường Đại học / Học viện theo học',
              ),
            )
          else if (_step == 2)
            DropdownButtonFormField<String>(
              initialValue: _jobType,
              decoration: const InputDecoration(
                labelText: 'Bước 3: Hình thức làm việc mong muốn',
              ),
              items: const [
                DropdownMenuItem(
                    value: 'FULL_TIME', child: Text('Toàn thời gian (Full-time)')),
                DropdownMenuItem(
                    value: 'INTERNSHIP', child: Text('Thực tập sinh (Internship)')),
                DropdownMenuItem(
                    value: 'PART_TIME', child: Text('Bán thời gian (Part-time)')),
              ],
              onChanged: (v) => setState(() => _jobType = v ?? 'FULL_TIME'),
            )
          else
            TextField(
              controller: _locCtrl,
              decoration: const InputDecoration(
                labelText: 'Bước 4: Thành phố làm việc ưu tiên',
              ),
            ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_step > 0)
                OutlinedButton(
                  onPressed: () => setState(() => _step--),
                  child: const Text('Quay lại'),
                )
              else
                const SizedBox.shrink(),
              ElevatedButton(
                onPressed: _submitting
                    ? null
                    : () {
                        if (_step < 3) {
                          setState(() => _step++);
                        } else {
                          _submitOnboarding();
                        }
                      },
                child: Text(_step < 3 ? 'Tiếp theo' : 'Hoàn tất Onboarding'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
