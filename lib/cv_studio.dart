import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'theme.dart';

class CvStudioPage extends StatefulWidget {
  final MoreJobApi api;
  final Map<String, dynamic>? initialProfile;
  final VoidCallback? onOpenCheckoutTemplateUnlock;

  const CvStudioPage({
    super.key,
    required this.api,
    this.initialProfile,
    this.onOpenCheckoutTemplateUnlock,
  });

  @override
  State<CvStudioPage> createState() => _CvStudioPageState();
}

class _CvStudioPageState extends State<CvStudioPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  bool _busy = false;
  List<dynamic> _cvs = [];
  List<dynamic> _templates = [];
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _activeCv;
  Map<String, dynamic>? _latestRevision;
  Map<String, bool> _templateUnlocked = {};

  // Editor state
  final _cvTitleCtrl = TextEditingController(text: 'CV Chuyên nghiệp');
  final _targetRoleCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _linkedinCtrl = TextEditingController();
  final _portfolioCtrl = TextEditingController();
  final _aiPromptCtrl = TextEditingController();

  List<Map<String, String>> _skills = [];
  List<Map<String, String>> _experiences = [];
  List<Map<String, String>> _educations = [];
  List<Map<String, String>> _projects = [];
  List<Map<String, String>> _certifications = [];
  List<Map<String, String>> _languages = [];

  int? _selectedTemplateId;
  String? _selectedTemplateKey;
  String? _previewHtml;
  String? _previewUrl;
  String? _artifactDownloadUrl;
  String? _renderStatusMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _profile = widget.initialProfile;
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cvTitleCtrl.dispose();
    _targetRoleCtrl.dispose();
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _summaryCtrl.dispose();
    _linkedinCtrl.dispose();
    _portfolioCtrl.dispose();
    _aiPromptCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.api.get('/students/me/cvs').catchError((_) => []),
        widget.api.get('/cv-templates').catchError((_) => []),
        if (_profile == null)
          widget.api.get('/students/me').catchError((_) => null)
        else
          Future.value(_profile),
      ]);
      _cvs = MoreJobApi.pageItems(results[0]);
      _templates = MoreJobApi.pageItems(results[1]);
      if (results[2] is Map<String, dynamic>) {
        _profile = results[2] as Map<String, dynamic>;
      }
      if (_templates.isNotEmpty && _selectedTemplateId == null) {
        final first = _templates.first;
        _selectedTemplateId = first['id'] is int
            ? first['id'] as int
            : int.tryParse('${first['id']}');
        _selectedTemplateKey =
            (first['code'] ?? first['templateKey'] ?? first['name'] ?? '')
                .toString();
      }
      _populateFromProfile(_profile);
      if (_cvs.isNotEmpty && _activeCv == null) {
        await _selectCv(_cvs.first as Map<String, dynamic>, switchTab: false);
      }
      await _checkTemplateAccess();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkTemplateAccess() async {
    final map = <String, bool>{};
    for (final t in _templates) {
      final key = (t['code'] ?? t['templateKey'] ?? '${t['id']}').toString();
      final isSpecial = t['special'] == true || t['isSpecial'] == true;
      if (!isSpecial) {
        map[key] = true;
        continue;
      }
      try {
        final res = await widget.api.get(
          '/cv-templates/access',
          query: {'templateKey': key},
        );
        map[key] = res is Map &&
            (res['allowed'] == true ||
                res['unlocked'] == true ||
                res['hasAccess'] == true);
      } catch (_) {
        map[key] = false;
      }
    }
    if (mounted) {
      setState(() => _templateUnlocked = map);
    }
  }

  void _populateFromProfile(Map<String, dynamic>? p) {
    if (p == null) return;
    if (_fullNameCtrl.text.isEmpty) {
      _fullNameCtrl.text = (p['fullName'] ?? '').toString();
    }
    if (_emailCtrl.text.isEmpty) {
      _emailCtrl.text = (p['email'] ?? '').toString();
    }
    if (_phoneCtrl.text.isEmpty) {
      _phoneCtrl.text = (p['phone'] ?? '').toString();
    }
    if (_locationCtrl.text.isEmpty) {
      _locationCtrl.text =
          (p['location'] ?? p['preferredLocations'] ?? '').toString();
    }
    if (_targetRoleCtrl.text.isEmpty) {
      _targetRoleCtrl.text =
          (p['major'] ?? p['headline'] ?? 'Software Engineer').toString();
    }
    if (_summaryCtrl.text.isEmpty) {
      _summaryCtrl.text = (p['bio'] ?? '').toString();
    }
    if (_educations.isEmpty && (p['university'] ?? '').toString().isNotEmpty) {
      _educations = [
        {
          'school': (p['university'] ?? '').toString(),
          'degree': (p['educationLevel'] ?? 'Cử nhân').toString(),
          'major': (p['major'] ?? '').toString(),
          'period': '${p['graduationYear'] ?? '2022 - 2026'}',
          'gpa': '${p['gpa'] ?? ''}',
        }
      ];
    }
  }

  Future<void> _selectCv(Map<String, dynamic> cv, {bool switchTab = true}) async {
    setState(() {
      _activeCv = cv;
      _cvTitleCtrl.text =
          (cv['title'] ?? cv['name'] ?? cv['fileName'] ?? 'CV').toString();
      _previewUrl = (cv['fileUrl'] ?? cv['previewUrl'])?.toString();
      _artifactDownloadUrl = (cv['downloadUrl'] ?? cv['fileUrl'])?.toString();
    });

    final cvId = cv['id'];
    if (cvId != null) {
      try {
        final rev =
            await widget.api.get('/students/me/cvs/$cvId/revisions/latest');
        if (rev is Map<String, dynamic>) {
          _latestRevision = rev;
          _hydrateEditorFromRevision(rev);
        }
      } catch (_) {
        _hydrateEditorFromCv(cv);
      }
    } else {
      _hydrateEditorFromCv(cv);
    }
    if (switchTab && mounted) {
      _tabController.animateTo(2);
    }
  }

  void _hydrateEditorFromCv(Map<String, dynamic> cv) {
    final content = cv['content'] ?? cv['structuredData'] ?? cv['data'];
    if (content is Map<String, dynamic>) {
      _hydrateStructuredMap(content);
    } else if (content is String && content.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(content);
        if (decoded is Map<String, dynamic>) {
          _hydrateStructuredMap(decoded);
        } else {
          _summaryCtrl.text = content;
        }
      } catch (_) {
        _summaryCtrl.text = content;
      }
    } else if (content is String && content.isNotEmpty) {
      _summaryCtrl.text = content;
    }
  }

  void _hydrateEditorFromRevision(Map<String, dynamic> rev) {
    final data = rev['data'] ??
        rev['structuredData'] ??
        rev['content'] ??
        rev['payload'];
    if (data is Map<String, dynamic>) {
      _hydrateStructuredMap(data);
    } else if (data is String && data.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          _hydrateStructuredMap(decoded);
        }
      } catch (_) {}
    }
    if (rev['previewHtml'] != null) {
      _previewHtml = rev['previewHtml'].toString();
    }
    if (mounted) setState(() {});
  }

  void _hydrateStructuredMap(Map<String, dynamic> map) {
    final personal = map['personalInfo'] is Map
        ? Map<String, dynamic>.from(map['personalInfo'] as Map)
        : map;
    _fullNameCtrl.text =
        (personal['fullName'] ?? personal['name'] ?? _fullNameCtrl.text)
            .toString();
    _emailCtrl.text =
        (personal['email'] ?? _emailCtrl.text).toString();
    _phoneCtrl.text =
        (personal['phone'] ?? _phoneCtrl.text).toString();
    _locationCtrl.text =
        (personal['location'] ?? personal['address'] ?? _locationCtrl.text)
            .toString();
    _targetRoleCtrl.text = (personal['targetRole'] ??
            personal['headline'] ??
            map['targetRole'] ??
            _targetRoleCtrl.text)
        .toString();
    _summaryCtrl.text =
        (map['summary'] ?? personal['summary'] ?? _summaryCtrl.text).toString();
    _linkedinCtrl.text =
        (personal['linkedin'] ?? _linkedinCtrl.text).toString();
    _portfolioCtrl.text =
        (personal['portfolio'] ?? personal['website'] ?? _portfolioCtrl.text)
            .toString();

    if (map['skills'] is List) {
      _skills = (map['skills'] as List).map((item) {
        if (item is Map) {
          return {
            'name': (item['name'] ?? item['skillName'] ?? '').toString(),
            'level': (item['level'] ?? item['proficiency'] ?? 'Intermediate')
                .toString(),
          };
        }
        return {'name': item.toString(), 'level': 'Intermediate'};
      }).toList();
    }

    if (map['experiences'] is List) {
      _experiences = (map['experiences'] as List).map((item) {
        if (item is Map) {
          return {
            'company': (item['company'] ?? item['organization'] ?? '').toString(),
            'role': (item['role'] ?? item['position'] ?? item['title'] ?? '')
                .toString(),
            'period': (item['period'] ?? item['duration'] ?? '').toString(),
            'description':
                (item['description'] ?? item['highlights'] ?? '').toString(),
          };
        }
        return {
          'company': '',
          'role': item.toString(),
          'period': '',
          'description': '',
        };
      }).toList();
    }

    if (map['educations'] is List || map['education'] is List) {
      final rawEdu = (map['educations'] ?? map['education']) as List;
      _educations = rawEdu.map((item) {
        if (item is Map) {
          return {
            'school': (item['school'] ?? item['university'] ?? '').toString(),
            'degree': (item['degree'] ?? 'Cử nhân').toString(),
            'major': (item['major'] ?? item['field'] ?? '').toString(),
            'period': (item['period'] ?? item['graduationYear'] ?? '').toString(),
            'gpa': (item['gpa'] ?? '').toString(),
          };
        }
        return {
          'school': item.toString(),
          'degree': '',
          'major': '',
          'period': '',
          'gpa': '',
        };
      }).toList();
    }

    if (map['projects'] is List) {
      _projects = (map['projects'] as List).map((item) {
        if (item is Map) {
          return {
            'name': (item['name'] ?? item['title'] ?? '').toString(),
            'role': (item['role'] ?? '').toString(),
            'tech': (item['tech'] ?? item['technologies'] ?? '').toString(),
            'description': (item['description'] ?? '').toString(),
          };
        }
        return {
          'name': item.toString(),
          'role': '',
          'tech': '',
          'description': '',
        };
      }).toList();
    }

    if (map['certifications'] is List) {
      _certifications = (map['certifications'] as List).map((item) {
        if (item is Map) {
          return {
            'name': (item['name'] ?? '').toString(),
            'issuer': (item['issuer'] ?? '').toString(),
            'year': (item['year'] ?? '').toString(),
          };
        }
        return {'name': item.toString(), 'issuer': '', 'year': ''};
      }).toList();
    }

    if (map['languages'] is List) {
      _languages = (map['languages'] as List).map((item) {
        if (item is Map) {
          return {
            'name': (item['name'] ?? item['language'] ?? '').toString(),
            'level': (item['level'] ?? 'Giao tiếp tốt').toString(),
          };
        }
        return {'name': item.toString(), 'level': 'Giao tiếp tốt'};
      }).toList();
    }
  }

  Map<String, dynamic> _buildStructuredPayload() {
    return {
      'title': _cvTitleCtrl.text.trim().isEmpty
          ? 'CV Chuyên nghiệp'
          : _cvTitleCtrl.text.trim(),
      'templateId': _selectedTemplateId,
      'templateKey': _selectedTemplateKey,
      'personalInfo': {
        'fullName': _fullNameCtrl.text.trim(),
        'targetRole': _targetRoleCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'linkedin': _linkedinCtrl.text.trim(),
        'portfolio': _portfolioCtrl.text.trim(),
        'summary': _summaryCtrl.text.trim(),
      },
      'summary': _summaryCtrl.text.trim(),
      'skills': _skills,
      'experiences': _experiences,
      'educations': _educations,
      'projects': _projects,
      'certifications': _certifications,
      'languages': _languages,
    };
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

  Future<void> _uploadPdfArtifact() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (file == null) return;
    setState(() => _busy = true);
    try {
      await widget.api.uploadCvArtifact(
        file,
        _cvTitleCtrl.text.trim().isEmpty ? file.name : _cvTitleCtrl.text.trim(),
      );
      _showMsg('Đã tải CV lên thành công!');
      await _loadAll();
    } catch (e) {
      try {
        await widget.api.uploadCv(file, file.name);
        _showMsg('Đã tải CV lên thành công!');
        await _loadAll();
      } catch (err) {
        _showMsg(err.toString(), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createCvFromTemplate(Map<String, dynamic> template) async {
    final id = template['id'] is int
        ? template['id'] as int
        : int.tryParse('${template['id']}');
    final key =
        (template['code'] ?? template['templateKey'] ?? '${template['id']}')
            .toString();
    final isSpecial =
        template['special'] == true || template['isSpecial'] == true;
    final hasAccess = _templateUnlocked[key] ?? !isSpecial;

    if (isSpecial && !hasAccess) {
      _showUnlockTemplateDialog(template);
      return;
    }

    setState(() {
      _selectedTemplateId = id;
      _selectedTemplateKey = key;
      _busy = true;
    });

    try {
      final res = await widget.api.post(
        '/students/me/cvs/from-template',
        body: {
          'templateId': id,
          'templateKey': key,
          'title':
              '${template['name'] ?? 'CV'} - ${_fullNameCtrl.text.isEmpty ? 'Ứng viên' : _fullNameCtrl.text}',
          'data': _buildStructuredPayload(),
        },
      );
      _showMsg('Đã khởi tạo CV từ mẫu ${template['name'] ?? key}!');
      await _loadAll();
      if (res is Map<String, dynamic>) {
        await _selectCv(res, switchTab: true);
      } else {
        _tabController.animateTo(2);
      }
    } catch (e) {
      // Fallback: open editor directly with selected template
      _showMsg(
        'Đã chọn mẫu ${template['name'] ?? key}. Bạn có thể chỉnh sửa và lưu ngay!',
      );
      _tabController.animateTo(2);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showUnlockTemplateDialog(Map<String, dynamic> template) {
    final key =
        (template['code'] ?? template['templateKey'] ?? '${template['id']}')
            .toString();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: MoreJobColors.brand),
            SizedBox(width: 8),
            Expanded(child: Text('Mở khóa mẫu CV Premium')),
          ],
        ),
        content: Text(
          'Mẫu "${template['name'] ?? key}" thuộc bộ sưu tập Special Pro. Bạn có muốn mở khóa qua PayOS hoặc gói Student AI Pro không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Để sau'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _unlockTemplateCheckout(template);
            },
            icon: const Icon(Icons.lock_open),
            label: const Text('Mở khóa ngay'),
          ),
        ],
      ),
    );
  }

  Future<void> _unlockTemplateCheckout(Map<String, dynamic> template) async {
    final key =
        (template['code'] ?? template['templateKey'] ?? '${template['id']}')
            .toString();
    setState(() => _busy = true);
    try {
      final session = await widget.api.post(
        '/billing/checkout-sessions',
        body: {
          'planCode': 'CV_TEMPLATE_UNLOCK',
          'templateKey': key,
          'returnUrl': 'https://morejob.vn/payment/result',
          'cancelUrl': 'https://morejob.vn/payment/result?cancelled=true',
        },
      );
      if (session is Map && session['checkoutUrl'] != null) {
        final uri = Uri.tryParse(session['checkoutUrl'].toString());
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else {
        widget.onOpenCheckoutTemplateUnlock?.call();
      }
    } catch (e) {
      _showMsg('Không thể tạo phiên thanh toán: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generateAiCv() async {
    setState(() => _busy = true);
    try {
      final res = await widget.api.post(
        '/students/me/ai/cvs/generate',
        body: {
          'title': _cvTitleCtrl.text.trim().isEmpty
              ? 'AI CV - ${_targetRoleCtrl.text.trim()}'
              : _cvTitleCtrl.text.trim(),
          'targetRole': _targetRoleCtrl.text.trim(),
          'templateId': _selectedTemplateId,
          'prompt': _aiPromptCtrl.text.trim(),
          'personalInfo': _buildStructuredPayload()['personalInfo'],
        },
      );
      _showMsg('AI đã tạo nội dung CV thành công!');
      if (res is Map<String, dynamic>) {
        _hydrateEditorFromCv(res);
      }
      await _loadAll();
      _tabController.animateTo(2);
    } catch (e) {
      _showMsg('Lỗi tạo CV bằng AI: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveRevisionAndPreview() async {
    setState(() => _busy = true);
    try {
      final payload = _buildStructuredPayload();
      final cvId = _activeCv?['id'];
      final revId = _latestRevision?['id'];

      if (cvId != null && revId != null) {
        final updated = await widget.api.put(
          '/students/me/cvs/$cvId/revisions/$revId',
          body: {'data': payload, 'title': _cvTitleCtrl.text.trim()},
        );
        if (updated is Map<String, dynamic>) {
          _latestRevision = updated;
        }
        final prev = await widget.api
            .post('/students/me/cvs/$cvId/revisions/$revId/preview');
        if (prev is Map) {
          _previewHtml = prev['html']?.toString();
          _previewUrl = prev['previewUrl']?.toString();
        }
        _showMsg('Đã lưu bản nháp CV & cập nhật bản xem trước!');
      } else if (cvId != null) {
        await widget.api.put(
          '/students/me/cvs/$cvId',
          body: {
            'title': _cvTitleCtrl.text.trim(),
            'content': jsonEncode(payload),
            'data': payload,
          },
        );
        try {
          final prev =
              await widget.api.post('/students/me/cvs/$cvId/preview');
          if (prev is Map) {
            _previewHtml = prev['html']?.toString();
            _previewUrl = prev['previewUrl']?.toString();
          }
        } catch (_) {}
        _showMsg('Đã cập nhật CV thành công!');
      } else {
        final created = await widget.api.post(
          '/students/me/cvs',
          body: {
            'title': _cvTitleCtrl.text.trim(),
            'templateId': _selectedTemplateId,
            'content': jsonEncode(payload),
            'data': payload,
          },
        );
        if (created is Map<String, dynamic>) {
          _activeCv = created;
        }
        await _loadAll();
        _showMsg('Đã tạo CV mới thành công!');
      }
      _tabController.animateTo(3);
    } catch (e) {
      _showMsg('Đã cập nhật bản xem trước cục bộ ($e)');
      _tabController.animateTo(3);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finalizeAndExportPdf() async {
    final cvId = _activeCv?['id'];
    if (cvId == null) {
      await _saveRevisionAndPreview();
      return;
    }
    setState(() {
      _busy = true;
      _renderStatusMessage = 'Đang kết xuất PDF chất lượng cao...';
    });
    try {
      final revId = _latestRevision?['id'];
      dynamic res;
      if (revId != null) {
        res = await widget.api
            .post('/students/me/cvs/$cvId/revisions/$revId/finalize');
      } else {
        res = await widget.api.post('/students/me/cvs/$cvId/finalize-latest');
      }

      if (res is Map) {
        final renderJobId = res['renderJobId'] ?? res['jobId'] ?? res['id'];
        final artifactId = res['artifactId'];
        if (renderJobId != null) {
          await _pollRenderJob(renderJobId);
        } else if (artifactId != null) {
          await _fetchArtifactDownloadUrl(artifactId);
        } else if (res['downloadUrl'] != null || res['fileUrl'] != null) {
          _artifactDownloadUrl =
              (res['downloadUrl'] ?? res['fileUrl']).toString();
        }
      }
      _showMsg('Đã hoàn tất xuất bản CV!');
    } catch (e) {
      _showMsg('Không thể kết xuất PDF trên máy chủ: $e', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _renderStatusMessage = null;
        });
      }
    }
  }

  Future<void> _pollRenderJob(dynamic renderJobId) async {
    for (var i = 0; i < 8; i++) {
      await Future.delayed(const Duration(seconds: 2));
      try {
        final job = await widget.api
            .get('/students/me/cvs/render-jobs/$renderJobId');
        if (job is Map) {
          final status = (job['status'] ?? '').toString().toUpperCase();
          if (mounted) {
            setState(() {
              _renderStatusMessage = 'Trạng thái kết xuất: $status';
            });
          }
          if (status == 'COMPLETED' || status == 'SUCCEEDED' || status == 'DONE') {
            final artifactId = job['artifactId'] ?? job['outputArtifactId'];
            if (artifactId != null) {
              await _fetchArtifactDownloadUrl(artifactId);
            } else if (job['downloadUrl'] != null) {
              _artifactDownloadUrl = job['downloadUrl'].toString();
            }
            return;
          }
          if (status == 'FAILED' || status == 'ERROR') {
            throw ApiException('Render job thất bại', 500);
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _fetchArtifactDownloadUrl(dynamic artifactId) async {
    try {
      final res = await widget.api
          .get('/students/me/cvs/artifacts/$artifactId/download-url');
      if (res is Map && (res['url'] != null || res['downloadUrl'] != null)) {
        setState(() {
          _artifactDownloadUrl = (res['url'] ?? res['downloadUrl']).toString();
        });
      }
    } catch (_) {}
  }

  Future<void> _setDefaultCv(dynamic id) async {
    try {
      await widget.api.patch('/students/me/cvs/$id/default');
      _showMsg('Đã đặt làm CV mặc định!');
      await _loadAll();
    } catch (e) {
      _showMsg(e.toString(), error: true);
    }
  }

  Future<void> _deleteCv(dynamic id) async {
    try {
      await widget.api.delete('/students/me/cvs/$id');
      if (_activeCv?['id'] == id) {
        _activeCv = null;
      }
      _showMsg('Đã xóa CV.');
      await _loadAll();
    } catch (e) {
      _showMsg(e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CV Studio & Kho mẫu chuẩn ATS',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: MoreJobColors.ink,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Tạo CV bằng AI, chọn mẫu chuyên nghiệp, chỉnh sửa trực tiếp & xuất PDF',
                          style: TextStyle(
                            fontSize: 12,
                            color: MoreJobColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _uploadPdfArtifact,
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: const Text('Tải PDF'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: MoreJobColors.brand,
                unselectedLabelColor: MoreJobColors.muted,
                indicatorColor: MoreJobColors.brand,
                tabs: [
                  Tab(text: 'Tủ CV (${_cvs.length})'),
                  Tab(text: 'Kho mẫu (${_templates.length})'),
                  const Tab(text: 'Trình sửa CV & AI'),
                  const Tab(text: 'Xem trước & Xuất PDF'),
                ],
              ),
            ],
          ),
        ),
        if (_busy || _renderStatusMessage != null)
          Container(
            width: double.infinity,
            color: MoreJobColors.brandSoft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _renderStatusMessage ?? 'Đang xử lý yêu cầu...',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: MoreJobColors.brandStrong,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMyCvsTab(),
              _buildTemplatesTab(),
              _buildStructuredEditorTab(),
              _buildPreviewTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMyCvsTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [MoreJobColors.navy, Color(0xFF1A4F8B)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tạo CV thông minh với AI hoặc mẫu ATS',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Đồng bộ dữ liệu hồ sơ sinh viên, chấm điểm từ khóa JD và xuất bản PDF.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _tabController.animateTo(1),
                            icon: const Icon(Icons.style, size: 16),
                            label: const Text('Chọn mẫu CV'),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
                            ),
                            onPressed: () => _tabController.animateTo(2),
                            icon: const Icon(Icons.auto_awesome, size: 16),
                            label: const Text('Tạo bằng AI'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_cvs.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      size: 48,
                      color: MoreJobColors.muted,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Bạn chưa có CV nào trong tủ hồ sơ',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Hãy tải lên file PDF có sẵn hoặc tạo CV mới từ kho mẫu chuẩn ATS.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: MoreJobColors.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _uploadPdfArtifact,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Tải CV PDF lên ngay'),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._cvs.map((item) {
              final cv = item as Map<String, dynamic>;
              final isDefault =
                  cv['isDefault'] == true || cv['defaultCv'] == true;
              final isSelected = _activeCv?['id'] == cv['id'];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isSelected
                        ? MoreJobColors.brand
                        : MoreJobColors.border,
                    width: isSelected ? 1.8 : 1,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: CircleAvatar(
                    backgroundColor: isDefault
                        ? MoreJobColors.brandSoft
                        : MoreJobColors.panel,
                    child: Icon(
                      isDefault ? Icons.star : Icons.description_outlined,
                      color: isDefault
                          ? MoreJobColors.brand
                          : MoreJobColors.navy,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          (cv['title'] ?? cv['fileName'] ?? 'CV #${cv['id']}')
                              .toString(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (isDefault)
                        const StatusPill(
                          label: 'Mặc định',
                          color: MoreJobColors.green,
                        ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cập nhật: ${cv['updatedAt'] ?? cv['createdAt'] ?? 'Mới tạo'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: MoreJobColors.muted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: () => _selectCv(cv, switchTab: true),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Chỉnh sửa'),
                            ),
                            if (!isDefault && cv['id'] != null)
                              TextButton.icon(
                                onPressed: () => _setDefaultCv(cv['id']),
                                icon: const Icon(Icons.check_circle_outline,
                                    size: 16),
                                label: const Text('Đặt mặc định'),
                              ),
                            if (cv['id'] != null)
                              TextButton.icon(
                                onPressed: () => _deleteCv(cv['id']),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: MoreJobColors.danger,
                                ),
                                label: const Text(
                                  'Xóa',
                                  style:
                                      TextStyle(color: MoreJobColors.danger),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTemplatesTab() {
    final displayTemplates = _templates.isNotEmpty
        ? _templates
        : [
            {
              'id': 1,
              'code': 'ATS_MODERN',
              'name': 'ATS Modern Clean',
              'category': 'Tech & Engineering',
              'special': false,
              'description':
                  'Bố cục 1 cột tối ưu máy quét ATS cho Fresher/Junior IT & Kỹ thuật.',
            },
            {
              'id': 2,
              'code': 'BANK_STANDARD',
              'name': 'Banking & Finance Standard',
              'category': 'Ngân hàng - Tài chính',
              'special': false,
              'description':
                  'Mẫu tiêu chuẩn Big4 & Ngân hàng thương mại cổ phần Việt Nam.',
            },
            {
              'id': 3,
              'code': 'EXECUTIVE_PRO',
              'name': 'Executive Gradient Pro',
              'category': 'Management / Creative',
              'special': true,
              'description':
                  'Mẫu CV cao cấp có điểm nhấn thương hiệu cá nhân và chỉ số KPI.',
            },
          ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: displayTemplates.length,
      itemBuilder: (context, index) {
        final t = displayTemplates[index] as Map<String, dynamic>;
        final key =
            (t['code'] ?? t['templateKey'] ?? '${t['id']}').toString();
        final isSpecial = t['special'] == true || t['isSpecial'] == true;
        final unlocked = _templateUnlocked[key] ?? !isSpecial;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 60,
                      decoration: BoxDecoration(
                        color: isSpecial
                            ? MoreJobColors.brandSoft
                            : MoreJobColors.panel,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: MoreJobColors.border),
                      ),
                      child: Icon(
                        isSpecial
                            ? Icons.workspace_premium
                            : Icons.article_outlined,
                        color: isSpecial
                            ? MoreJobColors.brand
                            : MoreJobColors.navy,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  (t['name'] ?? key).toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              StatusPill(
                                label: isSpecial
                                    ? (unlocked ? 'Pro (Đã mở)' : 'Special Pro')
                                    : 'Miễn phí',
                                color: isSpecial
                                    ? MoreJobColors.brand
                                    : MoreJobColors.green,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (t['category'] ?? 'Chuẩn ATS Đa ngành').toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: MoreJobColors.navy,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (t['description'] ??
                                    'Mẫu CV chuyên nghiệp tối ưu bố cục và điểm từ khóa.')
                                .toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: MoreJobColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (t['id'] != null)
                      TextButton.icon(
                        onPressed: () async {
                          try {
                            final ref = await widget.api.get(
                              '/cv-templates/${t['id']}/reference-url',
                            );
                            final url = ref is Map
                                ? (ref['url'] ?? ref['referenceUrl'])
                                : null;
                            if (url != null) {
                              final uri = Uri.tryParse(url.toString());
                              if (uri != null) {
                                await launchUrl(uri,
                                    mode: LaunchMode.externalApplication);
                                return;
                              }
                            }
                          } catch (_) {}
                          _tabController.animateTo(3);
                        },
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text('Xem mẫu'),
                      ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _createCvFromTemplate(t),
                      icon: Icon(
                        isSpecial && !unlocked
                            ? Icons.lock_open
                            : Icons.add_circle_outline,
                        size: 16,
                      ),
                      label: Text(
                        isSpecial && !unlocked
                            ? 'Mở khóa mẫu này'
                            : 'Dùng mẫu này',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStructuredEditorTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // AI Assistant generation banner
        Card(
          color: MoreJobColors.panel,
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
                        'Trợ lý AI viết & tối ưu nội dung CV',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _aiPromptCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText:
                        'Mô tả vị trí ứng tuyển hoặc điểm mạnh muốn AI nhấn mạnh',
                    hintText:
                        'VD: Ứng tuyển Fresher Backend Java tại ngân hàng, có đồ án Spring Boot &微服务...',
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _generateAiCv,
                    icon: const Icon(Icons.bolt, size: 18),
                    label: const Text('Tạo nội dung bằng AI'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Personal Info section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1. Thông tin định danh & Mục tiêu nghề nghiệp',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cvTitleCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Tiêu đề bản CV'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _fullNameCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Họ và tên'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _targetRoleCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Vị trí ứng tuyển'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _phoneCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Số điện thoại'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _locationCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Địa chỉ / Khu vực'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _linkedinCtrl,
                        decoration:
                            const InputDecoration(labelText: 'LinkedIn URL'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _portfolioCtrl,
                        decoration: const InputDecoration(
                            labelText: 'GitHub / Portfolio'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _summaryCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Tóm tắt mục tiêu nghề nghiệp (Executive Summary)',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Education section
        _buildDynamicSectionCard(
          title: '2. Học vấn (Education)',
          items: _educations,
          onAdd: () => setState(() {
            _educations.add({
              'school': '',
              'degree': 'Cử nhân',
              'major': '',
              'period': '2022 - 2026',
              'gpa': '',
            });
          }),
          itemBuilder: (idx, item) => Column(
            children: [
              TextField(
                controller: TextEditingController(text: item['school'])
                  ..selection = TextSelection.collapsed(
                      offset: (item['school'] ?? '').length),
                onChanged: (v) => item['school'] = v,
                decoration:
                    const InputDecoration(labelText: 'Trường Đại học / Học viện'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(text: item['major'])
                        ..selection = TextSelection.collapsed(
                            offset: (item['major'] ?? '').length),
                      onChanged: (v) => item['major'] = v,
                      decoration:
                          const InputDecoration(labelText: 'Chuyên ngành'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(text: item['gpa'])
                        ..selection = TextSelection.collapsed(
                            offset: (item['gpa'] ?? '').length),
                      onChanged: (v) => item['gpa'] = v,
                      decoration: const InputDecoration(labelText: 'GPA'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          onRemove: (idx) => setState(() => _educations.removeAt(idx)),
        ),
        const SizedBox(height: 12),
        // Experience section
        _buildDynamicSectionCard(
          title: '3. Kinh nghiệm làm việc / Thực tập',
          items: _experiences,
          onAdd: () => setState(() {
            _experiences.add({
              'company': '',
              'role': '',
              'period': '2025 - Hiện tại',
              'description': '',
            });
          }),
          itemBuilder: (idx, item) => Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(text: item['company'])
                        ..selection = TextSelection.collapsed(
                            offset: (item['company'] ?? '').length),
                      onChanged: (v) => item['company'] = v,
                      decoration:
                          const InputDecoration(labelText: 'Công ty / Tổ chức'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(text: item['role'])
                        ..selection = TextSelection.collapsed(
                            offset: (item['role'] ?? '').length),
                      onChanged: (v) => item['role'] = v,
                      decoration: const InputDecoration(labelText: 'Vị trí'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: TextEditingController(text: item['description'])
                  ..selection = TextSelection.collapsed(
                      offset: (item['description'] ?? '').length),
                onChanged: (v) => item['description'] = v,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Thành tựu & Trách nhiệm chính'),
              ),
            ],
          ),
          onRemove: (idx) => setState(() => _experiences.removeAt(idx)),
        ),
        const SizedBox(height: 12),
        // Projects section
        _buildDynamicSectionCard(
          title: '4. Dự án nổi bật (Projects)',
          items: _projects,
          onAdd: () => setState(() {
            _projects.add({
              'name': '',
              'role': 'Full-stack Developer',
              'tech': '',
              'description': '',
            });
          }),
          itemBuilder: (idx, item) => Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(text: item['name'])
                        ..selection = TextSelection.collapsed(
                            offset: (item['name'] ?? '').length),
                      onChanged: (v) => item['name'] = v,
                      decoration:
                          const InputDecoration(labelText: 'Tên dự án'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(text: item['tech'])
                        ..selection = TextSelection.collapsed(
                            offset: (item['tech'] ?? '').length),
                      onChanged: (v) => item['tech'] = v,
                      decoration:
                          const InputDecoration(labelText: 'Công nghệ sử dụng'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: TextEditingController(text: item['description'])
                  ..selection = TextSelection.collapsed(
                      offset: (item['description'] ?? '').length),
                onChanged: (v) => item['description'] = v,
                maxLines: 2,
                decoration:
                    const InputDecoration(labelText: 'Mô tả & kết quả đạt được'),
              ),
            ],
          ),
          onRemove: (idx) => setState(() => _projects.removeAt(idx)),
        ),
        const SizedBox(height: 12),
        // Skills section
        _buildDynamicSectionCard(
          title: '5. Kỹ năng chuyên môn & Ngoại ngữ',
          items: _skills,
          onAdd: () => setState(() {
            _skills.add({'name': '', 'level': 'Advanced'});
          }),
          itemBuilder: (idx, item) => Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: TextEditingController(text: item['name'])
                    ..selection = TextSelection.collapsed(
                        offset: (item['name'] ?? '').length),
                  onChanged: (v) => item['name'] = v,
                  decoration: const InputDecoration(labelText: 'Tên kỹ năng'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: item['level'])
                    ..selection = TextSelection.collapsed(
                        offset: (item['level'] ?? '').length),
                  onChanged: (v) => item['level'] = v,
                  decoration: const InputDecoration(labelText: 'Mức độ'),
                ),
              ),
            ],
          ),
          onRemove: (idx) => setState(() => _skills.removeAt(idx)),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _saveRevisionAndPreview,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Lưu & Xem trước'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _finalizeAndExportPdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Hoàn tất & Xuất PDF'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildDynamicSectionCard({
    required String title,
    required List<Map<String, String>> items,
    required VoidCallback onAdd,
    required Widget Function(int index, Map<String, String> item) itemBuilder,
    required void Function(int index) onRemove,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Thêm mục'),
                ),
              ],
            ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Chưa có dữ liệu. Nhấn "Thêm mục" để bổ sung.',
                  style: TextStyle(color: MoreJobColors.muted, fontSize: 12),
                ),
              )
            else
              ...items.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                return Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MoreJobColors.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: MoreJobColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Mục #${idx + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: MoreJobColors.navy,
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: MoreJobColors.danger,
                            ),
                            onPressed: () => onRemove(idx),
                          ),
                        ],
                      ),
                      itemBuilder(idx, item),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewTab() {
    final data = _buildStructuredPayload();
    final personal = data['personalInfo'] as Map<String, dynamic>;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _finalizeAndExportPdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Kết xuất PDF chuẩn ATS'),
              ),
            ),
            if (_previewUrl != null && _previewUrl!.isNotEmpty) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Mở bản xem trước trên trình duyệt',
                onPressed: () async {
                  final uri = Uri.tryParse(_previewUrl!);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.open_in_new),
              ),
            ],
            if (_artifactDownloadUrl != null &&
                _artifactDownloadUrl!.isNotEmpty) ...[
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final uri = Uri.tryParse(_artifactDownloadUrl!);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.download),
                label: const Text('Tải file PDF'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        if (_previewHtml != null && _previewHtml!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: StatusPill(
              label:
                  'Đã đồng bộ HTML Preview (${_previewHtml!.length} ký tự)',
              color: MoreJobColors.green,
            ),
          ),
        // Native Professional CV Preview Sheet matching web ProfessionalCvPreview
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MoreJobColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140F172A),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CV Header
              Container(
                padding: const EdgeInsets.only(bottom: 14),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: MoreJobColors.navy, width: 2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (personal['fullName'] ?? '').toString().isEmpty
                          ? 'HỌ VÀ TÊN ỨNG VIÊN'
                          : personal['fullName'].toString().toUpperCase(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: MoreJobColors.navy,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (personal['targetRole'] ?? '').toString().isEmpty
                          ? 'Vị trí ứng tuyển'
                          : personal['targetRole'].toString(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: MoreJobColors.brand,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      children: [
                        if ((personal['email'] ?? '').toString().isNotEmpty)
                          Text(
                            '✉ ${personal['email']}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        if ((personal['phone'] ?? '').toString().isNotEmpty)
                          Text(
                            '☎ ${personal['phone']}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        if ((personal['location'] ?? '').toString().isNotEmpty)
                          Text(
                            '📍 ${personal['location']}',
                            style: const TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if ((personal['summary'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 14),
                _buildCvPreviewHeading('MỤC TIÊU NGHỀ NGHIỆP'),
                const SizedBox(height: 6),
                Text(
                  personal['summary'].toString(),
                  style: const TextStyle(fontSize: 13, height: 1.45),
                ),
              ],
              if (_educations.isNotEmpty) ...[
                const SizedBox(height: 14),
                _buildCvPreviewHeading('HỌC VẤN'),
                const SizedBox(height: 6),
                ..._educations.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                e['school'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              e['period'] ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: MoreJobColors.muted,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${e['degree'] ?? ''} - ${e['major'] ?? ''}${e['gpa'] != null && e['gpa']!.isNotEmpty ? ' (GPA: ${e['gpa']})' : ''}',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (_experiences.isNotEmpty) ...[
                const SizedBox(height: 14),
                _buildCvPreviewHeading('KINH NGHIỆM LÀM VIỆC'),
                const SizedBox(height: 6),
                ..._experiences.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${e['role'] ?? ''} | ${e['company'] ?? ''}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              e['period'] ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: MoreJobColors.muted,
                              ),
                            ),
                          ],
                        ),
                        if ((e['description'] ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              e['description']!,
                              style:
                                  const TextStyle(fontSize: 12.5, height: 1.4),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              if (_projects.isNotEmpty) ...[
                const SizedBox(height: 14),
                _buildCvPreviewHeading('DỰ ÁN TIÊU BIỂU'),
                const SizedBox(height: 6),
                ..._projects.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${p['name'] ?? ''} (${p['tech'] ?? ''})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        if ((p['description'] ?? '').isNotEmpty)
                          Text(
                            p['description']!,
                            style: const TextStyle(fontSize: 12.5, height: 1.4),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              if (_skills.isNotEmpty) ...[
                const SizedBox(height: 14),
                _buildCvPreviewHeading('KỸ NĂNG CHUYÊN MÔN'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _skills
                      .map(
                        (s) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: MoreJobColors.panel,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${s['name']} • ${s['level']}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: MoreJobColors.navy,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCvPreviewHeading(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: MoreJobColors.navy,
        letterSpacing: 0.6,
      ),
    );
  }
}
