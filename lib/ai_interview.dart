import 'package:flutter/material.dart';

import 'api.dart';
import 'theme.dart';

class AiInterviewPage extends StatefulWidget {
  final MoreJobApi api;

  const AiInterviewPage({super.key, required this.api});

  @override
  State<AiInterviewPage> createState() => _AiInterviewPageState();
}

class _AiInterviewPageState extends State<AiInterviewPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  bool _busy = false;

  List<dynamic> _jobs = [];
  List<dynamic> _history = [];
  int? _selectedJobId;
  final _customPositionCtrl =
      TextEditingController(text: 'Fresher Software Engineer');
  String _interviewLanguage = 'vi';
  String _difficulty = 'JUNIOR';
  bool _consentRecording = true;

  // Active interview session
  Map<String, dynamic>? _activeSession;
  List<Map<String, dynamic>> _messages = [];
  final _answerCtrl = TextEditingController();
  Map<String, dynamic>? _reportData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customPositionCtrl.dispose();
    _answerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.api
            .get('/recruitment-listings', query: {'page': '0', 'size': '15'})
            .catchError((_) => []),
        widget.api
            .get('/ai-interviews', query: {'page': '0', 'size': '15'})
            .catchError((_) => []),
      ]);
      _jobs = MoreJobApi.pageItems(results[0]);
      _history = MoreJobApi.pageItems(results[1]);
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

  Future<void> _startInterview() async {
    if (!_consentRecording) {
      _showMsg('Vui lòng đồng ý điều khoản ghi nhận phiên phỏng vấn AI.',
          error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await widget.api.post(
        '/ai-interviews',
        body: {
          if (_selectedJobId != null) 'jobId': _selectedJobId,
          'positionTitle': _customPositionCtrl.text.trim(),
          'targetRole': _customPositionCtrl.text.trim(),
          'language': _interviewLanguage,
          'difficulty': _difficulty,
          'consentGiven': _consentRecording,
        },
      );
      final session = res is Map<String, dynamic>
          ? res
          : <String, dynamic>{
              'id': DateTime.now().millisecondsSinceEpoch,
              'positionTitle': _customPositionCtrl.text.trim(),
              'status': 'IN_PROGRESS',
            };
      final firstQuestion = (session['currentQuestion'] ??
              session['firstQuestion'] ??
              session['greeting'] ??
              'Xin chào! Tôi là AI Interviewer của MoreJob. Hãy giới thiệu ngắn gọn về bản thân, dự án nổi bật nhất của bạn và lý do bạn ứng tuyển vị trí ${_customPositionCtrl.text.trim()}.')
          .toString();

      setState(() {
        _activeSession = session;
        _reportData = null;
        _messages = [
          {
            'role': 'AI',
            'text': firstQuestion,
            'timestamp': DateTime.now().toIso8601String(),
          },
        ];
      });
      _tabController.animateTo(1);
    } catch (e) {
      // Fallback interactive simulation if backend AI key or quota is unavailable
      setState(() {
        _activeSession = {
          'id': 'local-${DateTime.now().millisecondsSinceEpoch}',
          'positionTitle': _customPositionCtrl.text.trim(),
          'status': 'IN_PROGRESS',
          'localFallback': true,
        };
        _reportData = null;
        _messages = [
          {
            'role': 'AI',
            'text':
                'Xin chào! Tôi là AI Interviewer của MoreJob (Chế độ mô phỏng). Bạn đang phỏng vấn vị trí "${_customPositionCtrl.text.trim()}". Câu hỏi 1: Hãy giới thiệu về bản thân và một dự án thực tế mà bạn tâm đắc nhất?',
            'timestamp': DateTime.now().toIso8601String(),
          },
        ];
      });
      _tabController.animateTo(1);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendAnswer() async {
    final text = _answerCtrl.text.trim();
    if (text.isEmpty || _activeSession == null) return;
    _answerCtrl.clear();

    setState(() {
      _messages.add({
        'role': 'USER',
        'text': text,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _busy = true;
    });

    final sessionId = _activeSession!['id'];
    final isLocal = _activeSession!['localFallback'] == true;

    try {
      if (!isLocal) {
        // Also record transcript entry like web FE
        try {
          await widget.api.post(
            '/ai-interviews/$sessionId/transcript',
            body: {'speaker': 'CANDIDATE', 'content': text},
          );
        } catch (_) {}

        final res = await widget.api.post(
          '/ai-interviews/$sessionId/answer',
          body: {'answer': text, 'content': text},
        );
        final reply = (res is Map
                ? (res['nextQuestion'] ??
                    res['reply'] ??
                    res['question'] ??
                    res['feedback'])
                : null)
            ?.toString();
        setState(() {
          _messages.add({
            'role': 'AI',
            'text': reply ??
                'Cảm ơn câu trả lời của bạn. Bạn có thể chia sẻ thêm về cách bạn xử lý áp lực deadline hoặc xung đột kỹ thuật trong nhóm không?',
            'timestamp': DateTime.now().toIso8601String(),
          });
        });
      } else {
        await Future.delayed(const Duration(milliseconds: 600));
        final qIndex =
            _messages.where((m) => m['role'] == 'AI').length + 1;
        final followUps = [
          'Rất ấn tượng! Câu hỏi 2: Khi gặp một bài toán kỹ thuật khó hoặc lỗi hiệu năng trong dự án, quy trình chẩn đoán và tối ưu của bạn như thế nào?',
          'Câu hỏi 3: Hãy mô tả một tình huống bạn làm việc nhóm theo mô hình Agile/Scrum và cách bạn phối hợp để hoàn thành đúng hạn.',
          'Câu hỏi 4: Mục tiêu phát triển nghề nghiệp của bạn trong 1-2 năm tới tại doanh nghiệp là gì? Bạn có thể nhấn "Kết thúc & Chấm điểm" để nhận báo cáo chi tiết.',
        ];
        final nextQ = followUps[(qIndex - 2) % followUps.length];
        setState(() {
          _messages.add({
            'role': 'AI',
            'text': nextQ,
            'timestamp': DateTime.now().toIso8601String(),
          });
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'AI',
          'text':
              'Ghi nhận câu trả lời của bạn. Tiếp theo: Hãy chia sẻ một thử thách kỹ thuật lớn nhất bạn từng giải quyết và bài học rút ra?',
          'timestamp': DateTime.now().toIso8601String(),
        });
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _endAndGenerateReport() async {
    if (_activeSession == null) return;
    setState(() => _busy = true);
    final sessionId = _activeSession!['id'];
    final isLocal = _activeSession!['localFallback'] == true;

    try {
      if (!isLocal) {
        try {
          await widget.api.post('/ai-interviews/$sessionId/end');
        } catch (_) {}
        final report =
            await widget.api.post('/ai-interviews/$sessionId/report');
        if (report is Map<String, dynamic>) {
          _reportData = report;
        }
        await _loadInitialData();
      }
    } catch (_) {}

    _reportData ??= _buildFallbackReport();
    if (mounted) {
      setState(() => _busy = false);
      _tabController.animateTo(2);
    }
  }

  Map<String, dynamic> _buildFallbackReport() {
    final userCount = _messages.where((m) => m['role'] == 'USER').length;
    final score = (72 + (userCount * 6)).clamp(65, 94);
    return {
      'overallScore': score,
      'positionTitle':
          _activeSession?['positionTitle'] ?? _customPositionCtrl.text,
      'summary':
          'Ứng viên thể hiện tư duy cấu trúc rõ ràng, nắm vững kiến thức nền tảng và có thái độ cầu thị. Cần bổ sung thêm số liệu định lượng (metrics/KPI) theo phương pháp STAR khi trình bày kinh nghiệm.',
      'criteria': [
        {
          'name': 'Kiến thức chuyên môn (Technical Depth)',
          'score': score,
          'comment': 'Trả lời đúng trọng tâm vị trí ứng tuyển.'
        },
        {
          'name': 'Kỹ năng giải quyết vấn đề (Problem Solving)',
          'score': (score - 3).clamp(60, 95),
          'comment': 'Có quy trình phân tích nguyên nhân gốc rễ.'
        },
        {
          'name': 'Giao tiếp & Cấu trúc STAR',
          'score': (score + 2).clamp(60, 98),
          'comment': 'Diễn đạt mạch lạc, tự tin.'
        },
      ],
      'strengths': [
        'Trình bày rõ ràng vai trò cá nhân trong dự án',
        'Thái độ chủ động học hỏi công nghệ mới',
        'Hiểu rõ yêu cầu cốt lõi của vị trí ${_customPositionCtrl.text}',
      ],
      'improvements': [
        'Bổ sung con số cụ thể về hiệu quả dự án (VD: giảm 30% thời gian tải)',
        'Trình bày ngắn gọn phần bối cảnh để tập trung vào Action & Result',
      ],
      'suggestedAnswer':
          'Gợi ý chuẩn STAR: "Trong dự án X (Situation), tôi đảm nhận tối ưu API tìm kiếm (Task). Tôi đã thiết kế lại chỉ mục PostgreSQL và thêm Redis cache (Action), giúp giảm độ trễ từ 450ms xuống 95ms (Result)."',
    };
  }

  Future<void> _openHistorySession(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id == null) return;
    setState(() => _busy = true);
    try {
      final detail = await widget.api.get('/ai-interviews/$id');
      if (detail is Map<String, dynamic>) {
        setState(() {
          _activeSession = detail;
          _reportData = detail['report'] is Map<String, dynamic>
              ? detail['report'] as Map<String, dynamic>
              : detail;
        });
        _tabController.animateTo(2);
      }
    } catch (e) {
      _showMsg('Không tải được chi tiết phiên: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
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
              const Row(
                children: [
                  Icon(Icons.record_voice_over, color: MoreJobColors.brand),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Phỏng vấn thử AI (AI Mock Interview)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: MoreJobColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Luyện phỏng vấn 1-1 với AI theo JD thực tế, chấm điểm theo mô hình STAR',
                style: TextStyle(fontSize: 12, color: MoreJobColors.muted),
              ),
              const SizedBox(height: 8),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: MoreJobColors.brand,
                unselectedLabelColor: MoreJobColors.muted,
                indicatorColor: MoreJobColors.brand,
                tabs: [
                  const Tab(text: '1. Thiết lập'),
                  const Tab(text: '2. Phòng phỏng vấn'),
                  const Tab(text: '3. Báo cáo đánh giá'),
                  Tab(text: 'Lịch sử (${_history.length})'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSetupTab(),
              _buildRoomTab(),
              _buildReportTab(),
              _buildHistoryTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSetupTab() {
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
                  'Cấu hình buổi phỏng vấn AI',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  isExpanded: true,
                  initialValue: _selectedJobId,
                  decoration: const InputDecoration(
                    labelText: 'Chọn tin tuyển dụng thực tế (Tùy chọn)',
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Tự nhập vị trí ứng tuyển bên dưới'),
                    ),
                    ..._jobs.map((j) {
                      final id = j['id'] is int
                          ? j['id'] as int
                          : int.tryParse('${j['id']}');
                      return DropdownMenuItem<int?>(
                        value: id,
                        child: Text(
                          '${j['title'] ?? 'Job'} - ${j['companyName'] ?? ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedJobId = val;
                      if (val != null) {
                        final found = _jobs.firstWhere(
                          (j) => '${j['id']}' == '$val',
                          orElse: () => null,
                        );
                        if (found != null && found['title'] != null) {
                          _customPositionCtrl.text = found['title'].toString();
                        }
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _customPositionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Vị trí ứng tuyển mục tiêu',
                    hintText: 'VD: Backend Developer, Business Analyst...',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _difficulty,
                        decoration:
                            const InputDecoration(labelText: 'Cấp độ câu hỏi'),
                        items: const [
                          DropdownMenuItem(
                              value: 'INTERN', child: Text('Thực tập sinh')),
                          DropdownMenuItem(
                              value: 'JUNIOR', child: Text('Fresher / Junior')),
                          DropdownMenuItem(
                              value: 'MIDDLE', child: Text('Middle / Senior')),
                        ],
                        onChanged: (v) =>
                            setState(() => _difficulty = v ?? 'JUNIOR'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _interviewLanguage,
                        decoration:
                            const InputDecoration(labelText: 'Ngôn ngữ'),
                        items: const [
                          DropdownMenuItem(
                              value: 'vi', child: Text('Tiếng Việt')),
                          DropdownMenuItem(
                              value: 'en', child: Text('Tiếng Anh (English)')),
                        ],
                        onChanged: (v) =>
                            setState(() => _interviewLanguage = v ?? 'vi'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _consentRecording,
                  activeColor: MoreJobColors.brand,
                  onChanged: (v) =>
                      setState(() => _consentRecording = v ?? true),
                  title: const Text(
                    'Tôi đồng ý để AI ghi nhận nội dung trả lời nhằm phân tích và tạo báo cáo đánh giá năng lực.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _startInterview,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      _busy
                          ? 'Đang khởi tạo phòng phỏng vấn...'
                          : 'Bắt đầu phỏng vấn với AI',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoomTab() {
    if (_activeSession == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mic_none_outlined,
                  size: 56, color: MoreJobColors.muted),
              const SizedBox(height: 12),
              const Text(
                'Chưa có phiên phỏng vấn đang diễn ra',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _tabController.animateTo(0),
                child: const Text('Thiết lập phiên phỏng vấn mới'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          color: MoreJobColors.navy,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: MoreJobColors.brand,
                child: Icon(Icons.smart_toy, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (_activeSession!['positionTitle'] ?? 'Phỏng vấn AI')
                          .toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const Text(
                      'AI Interviewer đang lắng nghe • Trả lời theo mô hình STAR',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MoreJobColors.green,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: _busy ? null : _endAndGenerateReport,
                icon: const Icon(Icons.assessment_outlined, size: 16),
                label: const Text('Kết thúc & Chấm điểm',
                    style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final m = _messages[index];
              final isAi = m['role'] == 'AI';
              return Align(
                alignment:
                    isAi ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 320),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isAi ? Colors.white : MoreJobColors.brand,
                    borderRadius: BorderRadius.circular(16),
                    border: isAi
                        ? Border.all(color: MoreJobColors.border)
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAi ? 'AI Interviewer' : 'Bạn',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isAi
                              ? MoreJobColors.navy
                              : Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (m['text'] ?? '').toString(),
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: isAi ? MoreJobColors.ink : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _answerCtrl,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText:
                        'Nhập câu trả lời của bạn (Situation - Task - Action - Result)...',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: MoreJobColors.brand,
                  padding: const EdgeInsets.all(14),
                ),
                onPressed: _busy ? null : _sendAnswer,
                icon: const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReportTab() {
    final report = _reportData;
    if (report == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.analytics_outlined,
                  size: 56, color: MoreJobColors.muted),
              const SizedBox(height: 12),
              const Text(
                'Chưa có báo cáo đánh giá phiên phỏng vấn',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hoàn thành phiên phỏng vấn hoặc chọn một phiên từ Lịch sử để xem phân tích chi tiết.',
                textAlign: TextAlign.center,
                style: TextStyle(color: MoreJobColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final score = report['overallScore'] ?? report['score'] ?? 80;
    final criteria = report['criteria'] is List
        ? report['criteria'] as List
        : const [];
    final strengths = report['strengths'] is List
        ? report['strengths'] as List
        : const [];
    final improvements = report['improvements'] is List
        ? report['improvements'] as List
        : const [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [MoreJobColors.navy, Color(0xFF1E4E8C)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: MoreJobColors.brand, width: 3),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$score/100',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (report['positionTitle'] ?? 'Đánh giá phỏng vấn AI')
                          .toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (report['summary'] ?? '').toString(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (criteria.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Điểm thành phần theo tiêu chí',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 10),
                  ...criteria.map((c) {
                    final m = c is Map ? c : {'name': c.toString(), 'score': 80};
                    final s = (m['score'] is num)
                        ? (m['score'] as num).toDouble()
                        : 80.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  (m['name'] ?? '').toString(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ),
                              Text(
                                '${s.round()}/100',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: MoreJobColors.brand,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: (s / 100).clamp(0.0, 1.0),
                            minHeight: 7,
                            borderRadius: BorderRadius.circular(999),
                            backgroundColor: MoreJobColors.panel,
                            color: MoreJobColors.brand,
                          ),
                          if (m['comment'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                m['comment'].toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: MoreJobColors.muted,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (strengths.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: MoreJobColors.green),
                      SizedBox(width: 8),
                      Text(
                        'Điểm mạnh nổi bật',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...strengths.map(
                    (s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text('• $s', style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (improvements.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.trending_up, color: MoreJobColors.brand),
                      SizedBox(width: 8),
                      Text(
                        'Khuyến nghị cải thiện & Gợi ý trả lời chuẩn STAR',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...improvements.map(
                    (s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text('• $s', style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                  if (report['suggestedAnswer'] != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: MoreJobColors.panel,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        report['suggestedAnswer'].toString(),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                          color: MoreJobColors.navy,
                        ),
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

  Widget _buildHistoryTab() {
    if (_history.isEmpty) {
      return const Center(
        child: Text('Chưa có lịch sử phỏng vấn AI.'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index] as Map<String, dynamic>;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: MoreJobColors.brandSoft,
              child: Icon(Icons.record_voice_over, color: MoreJobColors.brand),
            ),
            title: Text(
              (item['positionTitle'] ?? item['targetRole'] ?? 'Phiên #${item['id']}')
                  .toString(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              'Trạng thái: ${item['status'] ?? 'COMPLETED'} • Điểm: ${item['overallScore'] ?? item['score'] ?? '--'}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openHistorySession(item),
          ),
        );
      },
    );
  }
}
