import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'api.dart';
import 'theme.dart';

class AdminPortalPage extends StatefulWidget {
  final MoreJobApi api;
  final VoidCallback onLogout;

  const AdminPortalPage({
    super.key,
    required this.api,
    required this.onLogout,
  });

  @override
  State<AdminPortalPage> createState() => _AdminPortalPageState();
}

class _AdminPortalPageState extends State<AdminPortalPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  bool _busy = false;

  // Sourced jobs state
  List<dynamic> _sourcedJobs = [];
  String _statusFilter = '';
  final _keywordCtrl = TextEditingController();

  // CV templates state
  List<dynamic> _cvTemplates = [];
  final _tplCodeCtrl = TextEditingController();
  final _tplNameCtrl = TextEditingController();
  final _tplCategoryCtrl = TextEditingController(text: 'ATS Standard');
  bool _tplSpecial = false;
  Map<String, dynamic>? _inspectResult;

  // Student CVs management state
  final _studentIdCtrl = TextEditingController();
  final _cvIdCtrl = TextEditingController();
  final _adminCvTitleCtrl = TextEditingController();
  final _adminCvContentCtrl = TextEditingController();
  Map<String, dynamic>? _loadedAdminCv;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAdminData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _keywordCtrl.dispose();
    _tplCodeCtrl.dispose();
    _tplNameCtrl.dispose();
    _tplCategoryCtrl.dispose();
    _studentIdCtrl.dispose();
    _cvIdCtrl.dispose();
    _adminCvTitleCtrl.dispose();
    _adminCvContentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.api.get(
          '/admin/sourced-jobs',
          query: {
            'page': '0',
            'size': '25',
            if (_statusFilter.isNotEmpty) 'reviewStatus': _statusFilter,
            if (_keywordCtrl.text.trim().isNotEmpty)
              'keyword': _keywordCtrl.text.trim(),
          },
        ).catchError((_) => []),
        widget.api.get('/admin/cv-templates').catchError((_) => []),
      ]);
      _sourcedJobs = MoreJobApi.pageItems(results[0]);
      _cvTemplates = MoreJobApi.pageItems(results[1]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMsg(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? MoreJobColors.danger : MoreJobColors.navy,
      ),
    );
  }

  // --- Sourced Jobs Actions ---
  Future<void> _reviewSourcedJob(
    dynamic jobId,
    String status, {
    String? note,
  }) async {
    setState(() => _busy = true);
    try {
      await widget.api.patch(
        '/admin/sourced-jobs/$jobId/review',
        body: {
          'reviewStatus': status,
          'status': status,
          if (note != null && note.isNotEmpty) 'reviewNote': note,
        },
      );
      _showMsg('Đã cập nhật trạng thái duyệt ($status) cho tin #$jobId');
      await _loadAdminData();
    } catch (e) {
      _showMsg(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _collectCompanyRegistry(dynamic jobId) async {
    setState(() => _busy = true);
    try {
      await widget.api
          .post('/admin/sourced-jobs/$jobId/company-registry/collect');
      _showMsg('Đã thu thập thông tin đăng ký doanh nghiệp cho tin #$jobId');
      await _loadAdminData();
    } catch (e) {
      _showMsg(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showEmployerLinkModal(Map<String, dynamic> job) {
    final employerIdCtrl = TextEditingController(
      text: (job['employerId'] ?? job['companyId'] ?? '').toString(),
    );
    final taxCodeCtrl = TextEditingController(
      text: (job['taxCode'] ?? '').toString(),
    );
    final companyNameCtrl = TextEditingController(
      text: (job['companyName'] ?? '').toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Liên kết Doanh nghiệp • Tin #${job['id']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: employerIdCtrl,
                decoration:
                    const InputDecoration(labelText: 'Employer / Company ID'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: companyNameCtrl,
                decoration:
                    const InputDecoration(labelText: 'Tên pháp nhân công ty'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: taxCodeCtrl,
                decoration:
                    const InputDecoration(labelText: 'Mã số thuế (Tax Code)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.api.put(
                  '/admin/sourced-jobs/${job['id']}/company-registry',
                  body: {
                    'companyName': companyNameCtrl.text.trim(),
                    'taxCode': taxCodeCtrl.text.trim(),
                  },
                );
                _showMsg('Đã lưu Company Registry!');
                await _loadAdminData();
              } catch (e) {
                _showMsg(e.toString(), error: true);
              }
            },
            child: const Text('Lưu Registry'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.api.patch(
                  '/admin/sourced-jobs/${job['id']}/employer-link',
                  body: {
                    'employerId': int.tryParse(employerIdCtrl.text.trim()) ??
                        employerIdCtrl.text.trim(),
                  },
                );
                _showMsg('Đã liên kết Employer thành công!');
                await _loadAdminData();
              } catch (e) {
                _showMsg(e.toString(), error: true);
              }
            },
            child: const Text('Gắn Employer'),
          ),
        ],
      ),
    );
  }

  // --- CV Templates Actions ---
  Future<void> _inspectPdfTemplate() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (file == null) return;

    setState(() => _busy = true);
    try {
      final res = await widget.api.inspectAdminCvTemplate(file);
      setState(() => _inspectResult = res);
      _showMsg('Đã phân tích cấu trúc PDF Template!');
    } catch (e) {
      _showMsg(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadNewPdfTemplate() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (file == null) return;

    setState(() => _busy = true);
    try {
      await widget.api.createAdminPdfTemplate(
        displayName: _tplNameCtrl.text.trim().isEmpty
            ? file.name
            : _tplNameCtrl.text.trim(),
        templateKey: _tplCodeCtrl.text.trim().isEmpty
            ? 'TPL_${DateTime.now().millisecondsSinceEpoch}'
            : _tplCodeCtrl.text.trim(),
        category: _tplCategoryCtrl.text.trim(),
        featured: _tplSpecial,
        referenceFile: file,
      );
      _showMsg('Đã tạo mẫu CV PDF mới thành công!');
      await _loadAdminData();
    } catch (e) {
      _showMsg(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _templateAction(dynamic id, String action) async {
    setState(() => _busy = true);
    try {
      await widget.api.post('/admin/cv-templates/$id/$action');
      _showMsg('Đã thực hiện "$action" cho mẫu #$id!');
      await _loadAdminData();
    } catch (e) {
      _showMsg(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleTemplatePricing(dynamic id, bool special) async {
    setState(() => _busy = true);
    try {
      await widget.api.post(
        '/admin/cv-templates/$id/pricing',
        query: {'special': special.toString()},
      );
      _showMsg(
          'Đã cập nhật phân hạng mẫu #$id thành ${special ? 'Special Pro' : 'Free'}!');
      await _loadAdminData();
    } catch (e) {
      _showMsg(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // --- Admin Student CVs CRUD ---
  Future<void> _loadAdminCvById() async {
    final id = _cvIdCtrl.text.trim();
    if (id.isEmpty) return;
    setState(() => _busy = true);
    try {
      final res = await widget.api.get('/admin/cvs/$id');
      if (res is Map<String, dynamic>) {
        setState(() {
          _loadedAdminCv = res;
          _adminCvTitleCtrl.text = (res['title'] ?? '').toString();
          _adminCvContentCtrl.text =
              (res['content'] ?? res['data'] ?? '').toString();
        });
      }
    } catch (e) {
      _showMsg(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createAdminCvForStudent() async {
    final studentId = _studentIdCtrl.text.trim();
    if (studentId.isEmpty) {
      _showMsg('Vui lòng nhập Student Profile ID', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await widget.api.post(
        '/admin/students/$studentId/cvs',
        body: {
          'title': _adminCvTitleCtrl.text.trim(),
          'content': _adminCvContentCtrl.text.trim(),
        },
      );
      if (res is Map<String, dynamic>) {
        setState(() => _loadedAdminCv = res);
      }
      _showMsg('Đã tạo CV cho sinh viên #$studentId!');
    } catch (e) {
      _showMsg(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateAdminCv() async {
    final id = _cvIdCtrl.text.trim();
    if (id.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.api.put(
        '/admin/cvs/$id',
        body: {
          'title': _adminCvTitleCtrl.text.trim(),
          'content': _adminCvContentCtrl.text.trim(),
        },
      );
      _showMsg('Đã cập nhật CV #$id!');
    } catch (e) {
      _showMsg(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAdminCv() async {
    final id = _cvIdCtrl.text.trim();
    if (id.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.api.delete('/admin/cvs/$id');
      setState(() => _loadedAdminCv = null);
      _showMsg('Đã xóa CV #$id!');
    } catch (e) {
      _showMsg(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            MoreJobLogoText(fontSize: 20),
            SizedBox(width: 10),
            StatusPill(label: 'ADMIN PORTAL', color: MoreJobColors.navy),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadAdminData,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: MoreJobColors.brand,
          unselectedLabelColor: MoreJobColors.muted,
          indicatorColor: MoreJobColors.brand,
          tabs: [
            Tab(text: 'Duyệt việc làm thu thập (${_sourcedJobs.length})'),
            Tab(text: 'Quản trị Mẫu CV (${_cvTemplates.length})'),
            const Tab(text: 'Quản lý CV Sinh viên'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSourcedJobsTab(),
                _buildCvTemplatesAdminTab(),
                _buildAdminStudentCvsTab(),
              ],
            ),
    );
  }

  Widget _buildSourcedJobsTab() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keywordCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Tìm theo tiêu đề hoặc công ty...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => _loadAdminData(),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _statusFilter,
                items: const [
                  DropdownMenuItem(value: '', child: Text('Tất cả')),
                  DropdownMenuItem(value: 'PENDING', child: Text('Chờ duyệt')),
                  DropdownMenuItem(value: 'APPROVED', child: Text('Đã duyệt')),
                  DropdownMenuItem(value: 'REJECTED', child: Text('Từ chối')),
                ],
                onChanged: (v) {
                  setState(() => _statusFilter = v ?? '');
                  _loadAdminData();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _sourcedJobs.isEmpty
              ? const Center(child: Text('Không có tin tuyển dụng thu thập.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sourcedJobs.length,
                  itemBuilder: (context, index) {
                    final job = _sourcedJobs[index] as Map<String, dynamic>;
                    final status =
                        (job['reviewStatus'] ?? job['status'] ?? 'PENDING')
                            .toString();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    (job['title'] ?? 'Tin #${job['id']}')
                                        .toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                StatusPill(
                                  label: status,
                                  color: status == 'APPROVED'
                                      ? MoreJobColors.green
                                      : status == 'REJECTED'
                                          ? MoreJobColors.danger
                                          : MoreJobColors.brand,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${job['companyName'] ?? 'Chưa rõ công ty'} • ${job['location'] ?? 'Việt Nam'} • Nguồn: ${job['sourcePlatform'] ?? job['source'] ?? 'Crawler'}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: MoreJobColors.muted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: MoreJobColors.green,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  onPressed: _busy
                                      ? null
                                      : () => _reviewSourcedJob(
                                          job['id'], 'APPROVED'),
                                  icon: const Icon(Icons.check, size: 16),
                                  label: const Text('Duyệt đăng'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => _reviewSourcedJob(
                                          job['id'], 'REJECTED'),
                                  icon: const Icon(Icons.close,
                                      size: 16, color: MoreJobColors.danger),
                                  label: const Text(
                                    'Từ chối',
                                    style:
                                        TextStyle(color: MoreJobColors.danger),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _showEmployerLinkModal(job),
                                  icon: const Icon(Icons.business, size: 16),
                                  label: const Text('Employer / Registry'),
                                ),
                                TextButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () =>
                                          _collectCompanyRegistry(job['id']),
                                  icon: const Icon(Icons.sync, size: 16),
                                  label: const Text('Thu thập MST'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCvTemplatesAdminTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tải lên & Kiểm tra Mẫu CV PDF mới',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tplCodeCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Mã mẫu (Code)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _tplNameCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Tên hiển thị'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tplCategoryCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Danh mục ngành'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Switch(
                      value: _tplSpecial,
                      onChanged: (v) => setState(() => _tplSpecial = v),
                    ),
                    const Text('Special Pro'),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _inspectPdfTemplate,
                      icon: const Icon(Icons.plagiarism_outlined),
                      label: const Text('Inspect PDF Fields'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _busy ? null : _uploadNewPdfTemplate,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Tải lên PDF Template'),
                    ),
                  ],
                ),
                if (_inspectResult != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MoreJobColors.panel,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Kết quả Inspect: $_inspectResult',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ..._cvTemplates.map((item) {
          final t = item as Map<String, dynamic>;
          final isSpecial = t['special'] == true || t['isSpecial'] == true;
          final status = (t['status'] ?? 'ACTIVE').toString();
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${t['name'] ?? t['code'] ?? 'Template'} (#${t['id']})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      StatusPill(
                        label: isSpecial ? 'Special Pro' : 'Free',
                        color: isSpecial
                            ? MoreJobColors.brand
                            : MoreJobColors.green,
                      ),
                      const SizedBox(width: 6),
                      StatusPill(label: status, color: MoreJobColors.navy),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => _templateAction(t['id'], 'validate'),
                        child: const Text('Validate'),
                      ),
                      OutlinedButton(
                        onPressed: () => _templateAction(t['id'], 'preview'),
                        child: const Text('Preview'),
                      ),
                      ElevatedButton(
                        onPressed: () => _templateAction(t['id'], 'publish'),
                        child: const Text('Publish'),
                      ),
                      TextButton(
                        onPressed: () => _templateAction(t['id'], 'deactivate'),
                        child: const Text('Deactivate'),
                      ),
                      TextButton(
                        onPressed: () =>
                            _toggleTemplatePricing(t['id'], !isSpecial),
                        child: Text(
                            isSpecial ? 'Chuyển về Free' : 'Đặt làm Special'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAdminStudentCvsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tra cứu & Chỉnh sửa CV Sinh viên (/admin/cvs)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cvIdCtrl,
                        decoration:
                            const InputDecoration(labelText: 'CV ID cần tra cứu'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _busy ? null : _loadAdminCvById,
                      child: const Text('Tải CV'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _studentIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Student Profile ID (Khi tạo CV mới cho SV)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _adminCvTitleCtrl,
                  decoration: const InputDecoration(labelText: 'Tiêu đề CV'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _adminCvContentCtrl,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Nội dung / JSON dữ liệu CV',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _busy ? null : _createAdminCvForStudent,
                      icon: const Icon(Icons.add),
                      label: const Text('Tạo CV cho SV'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _updateAdminCv,
                      icon: const Icon(Icons.save),
                      label: const Text('Cập nhật CV'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _deleteAdminCv,
                      icon: const Icon(Icons.delete_outline,
                          color: MoreJobColors.danger),
                      label: const Text(
                        'Xóa CV',
                        style: TextStyle(color: MoreJobColors.danger),
                      ),
                    ),
                  ],
                ),
                if (_loadedAdminCv != null) ...[
                  const Divider(height: 24),
                  Text(
                    'Dữ liệu CV đã tải: #${_loadedAdminCv!['id']} - ${_loadedAdminCv!['title'] ?? ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: MoreJobColors.navy,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
