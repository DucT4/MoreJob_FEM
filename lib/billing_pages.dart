import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'theme.dart';

class BillingPricingPage extends StatefulWidget {
  final MoreJobApi api;
  final int? activeMatchBatchId;

  const BillingPricingPage({
    super.key,
    required this.api,
    this.activeMatchBatchId,
  });

  @override
  State<BillingPricingPage> createState() => _BillingPricingPageState();
}

class _BillingPricingPageState extends State<BillingPricingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  bool _busy = false;

  List<dynamic> _plans = [];
  Map<String, dynamic>? _subscription;
  List<dynamic> _jobs = [];
  int? _selectedJobIdForAi;
  Map<String, dynamic>? _jobMatchAnalysis;

  // Checkout / Order tracking
  final _orderIdCtrl = TextEditingController();
  Map<String, dynamic>? _currentOrder;
  Timer? _pollTimer;

  static const _defaultPlans = [
    {
      'code': 'STUDENT_AI_PRO',
      'name': 'Gói Student AI Pro (30 ngày)',
      'price': 99000,
      'currency': 'VND',
      'badge': 'Phổ biến nhất',
      'description':
          'Mở khóa toàn bộ tính năng AI: Tạo CV bằng AI không giới hạn, Phân tích độ khớp CV-JD chuyên sâu, Phỏng vấn thử AI & Mở khóa mẫu CV Special.',
      'features': [
        'Tạo & tối ưu CV bằng AI không giới hạn',
        'Phân tích độ tương thích CV với mọi JD (/students/me/ai/job-match)',
        'Phỏng vấn thử AI 1-1 kèm báo cáo STAR chi tiết',
        'Ưu tiên hiển thị hồ sơ với Nhà tuyển dụng hàng đầu',
      ],
    },
    {
      'code': 'JOB_MATCH_3',
      'name': 'Mở khóa Top 3 Việc làm Phù hợp',
      'price': 19000,
      'currency': 'VND',
      'badge': 'Tiết kiệm',
      'description':
          'Mở khóa chi tiết 3 công việc khớp nhất từ kết quả phân tích CV Match Batch của bạn.',
      'features': [
        'Xem đầy đủ thông tin công ty & mức lương Top 3 việc làm',
        'Xem điểm tương thích kỹ năng & từ khóa còn thiếu',
        'Ứng tuyển trực tiếp 1-click',
      ],
    },
    {
      'code': 'JOB_MATCH_5_V2',
      'name': 'Mở khóa Top 5 Việc làm + Gợi ý AI',
      'price': 29000,
      'currency': 'VND',
      'badge': 'Tối ưu',
      'description':
          'Mở khóa trọn bộ 5 việc làm khớp nhất cùng nhận xét cải thiện CV từ AI.',
      'features': [
        'Toàn bộ quyền lợi gói Top 3 + thêm 2 vị trí tiềm năng cao',
        'Chiến lược chỉnh sửa CV riêng cho từng vị trí',
        'Hỗ trợ thanh toán nhanh qua mã QR PayOS',
      ],
    },
    {
      'code': 'CV_TEMPLATE_UNLOCK',
      'name': 'Mở khóa Mẫu CV Special Pro',
      'price': 15000,
      'currency': 'VND',
      'badge': 'Lẻ theo mẫu',
      'description':
          'Sở hữu vĩnh viễn mẫu CV thiết kế cao cấp và xuất PDF chất lượng in ấn.',
      'features': [
        'Mở khóa mẫu CV Special Pro đã chọn',
        'Xuất file PDF chuẩn ATS không đóng dấu',
        'Lưu trữ phiên bản chỉnh sửa không giới hạn',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBillingData();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabController.dispose();
    _orderIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBillingData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.api.get('/billing/plans').catchError((_) => []),
        widget.api.get('/api/subscriptions/me').catchError((_) => null),
        widget.api
            .get('/recruitment-listings', query: {'page': '0', 'size': '15'})
            .catchError((_) => []),
      ]);
      final fetchedPlans = MoreJobApi.pageItems(results[0]);
      _plans = fetchedPlans.isNotEmpty ? fetchedPlans : _defaultPlans;
      if (results[1] is Map<String, dynamic>) {
        _subscription = results[1] as Map<String, dynamic>;
      }
      _jobs = MoreJobApi.pageItems(results[2]);
      if (_jobs.isNotEmpty && _selectedJobIdForAi == null) {
        final firstId = _jobs.first['id'];
        _selectedJobIdForAi =
            firstId is int ? firstId : int.tryParse('$firstId');
      }
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

  String _formatVnd(dynamic v) {
    final numVal =
        v is num ? v.round() : int.tryParse(v?.toString() ?? '') ?? 0;
    final str = numVal.toString();
    final buf = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
      buf.write(str[i]);
    }
    return '${buf.toString()} đ';
  }

  Future<void> _startCheckout(Map<String, dynamic> plan) async {
    final code = (plan['code'] ?? plan['planCode'] ?? 'STUDENT_AI_PRO')
        .toString();
    setState(() => _busy = true);
    try {
      final body = <String, dynamic>{
        'planCode': code,
        'returnUrl': 'https://morejob.vn/payment/result',
        'cancelUrl': 'https://morejob.vn/payment/result?cancelled=true',
      };
      if (widget.activeMatchBatchId != null &&
          (code == 'JOB_MATCH_3' || code == 'JOB_MATCH_5_V2')) {
        body['matchBatchId'] = widget.activeMatchBatchId;
      }

      final session =
          await widget.api.post('/billing/checkout-sessions', body: body);
      if (session is Map<String, dynamic>) {
        final orderId =
            session['orderId'] ?? session['orderCode'] ?? session['id'];
        if (orderId != null) {
          _orderIdCtrl.text = orderId.toString();
          _currentOrder = session;
          _startOrderPolling(orderId.toString());
        }
        final checkoutUrl =
            session['checkoutUrl'] ?? session['paymentUrl'] ?? session['url'];
        if (checkoutUrl != null) {
          final uri = Uri.tryParse(checkoutUrl.toString());
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
        _tabController.animateTo(2);
        _showMsg('Đã khởi tạo phiên thanh toán PayOS!');
      }
    } catch (e) {
      _showMsg('Không thể khởi tạo PayOS Checkout: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startOrderPolling(String orderId) {
    _pollTimer?.cancel();
    var ticks = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      ticks++;
      if (ticks > 20 || !mounted) {
        timer.cancel();
        return;
      }
      await _checkOrderStatus(orderId, silent: true);
    });
  }

  Future<void> _checkOrderStatus(String orderId, {bool silent = false}) async {
    if (orderId.trim().isEmpty) return;
    if (!silent) setState(() => _busy = true);
    try {
      final res = await widget.api.get('/billing/orders/${orderId.trim()}');
      if (res is Map<String, dynamic>) {
        setState(() => _currentOrder = res);
        final status = (res['status'] ?? '').toString().toUpperCase();
        if (status == 'PAID' || status == 'COMPLETED' || status == 'SUCCESS') {
          _pollTimer?.cancel();
          _showMsg('Thanh toán thành công! Quyền lợi đã được kích hoạt.');
          await _loadBillingData();
        }
      }
    } catch (e) {
      if (!silent) {
        _showMsg('Không tìm thấy đơn hàng #$orderId: $e', error: true);
      }
    } finally {
      if (!silent && mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runAiJobMatchAnalysis() async {
    if (_selectedJobIdForAi == null) return;
    setState(() => _busy = true);
    try {
      final res = await widget.api.post(
        '/students/me/ai/job-match',
        body: {'jobId': _selectedJobIdForAi},
      );
      if (res is Map<String, dynamic>) {
        setState(() => _jobMatchAnalysis = res);
      }
      _showMsg('Đã hoàn tất phân tích độ khớp CV - JD bằng AI!');
    } catch (e) {
      _showMsg('Lỗi phân tích AI: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final isProActive = _subscription != null &&
        ((_subscription!['active'] == true) ||
            (_subscription!['status']?.toString().toUpperCase() == 'ACTIVE'));

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
                    child: Text(
                      'Nâng cấp Tài khoản & Thanh toán PayOS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: MoreJobColors.ink,
                      ),
                    ),
                  ),
                  StatusPill(
                    label: isProActive ? 'Student AI Pro' : 'Tài khoản Free',
                    color: isProActive
                        ? MoreJobColors.green
                        : MoreJobColors.brand,
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
                tabs: const [
                  Tab(text: 'Bảng giá & Gói dịch vụ'),
                  Tab(text: 'Đặc quyền AI Pro & Hóa đơn'),
                  Tab(text: 'Kiểm tra Đơn hàng PayOS'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPlansTab(),
              _buildActivePremiumTab(isProActive),
              _buildOrderTrackingTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlansTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _plans.length,
      itemBuilder: (context, index) {
        final p = _plans[index] as Map<String, dynamic>;
        final code = (p['code'] ?? p['planCode'] ?? '').toString();
        final isHighlight = code == 'STUDENT_AI_PRO' || code == 'JOB_MATCH_5_V2';
        final features = p['features'] is List
            ? (p['features'] as List).map((e) => e.toString()).toList()
            : <String>[
                'Kích hoạt tức thì sau khi quét QR PayOS',
                'Đồng bộ quyền lợi trên cả Web và Mobile App',
              ];

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: isHighlight ? MoreJobColors.brand : MoreJobColors.border,
              width: isHighlight ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (p['name'] ?? code).toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (p['badge'] != null)
                      StatusPill(
                        label: p['badge'].toString(),
                        color: MoreJobColors.brand,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _formatVnd(p['price'] ?? p['amount'] ?? 29000),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: MoreJobColors.navy,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  (p['description'] ?? '').toString(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: MoreJobColors.muted,
                  ),
                ),
                const Divider(height: 22),
                ...features.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 16,
                          color: MoreJobColors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            f,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : () => _startCheckout(p),
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: const Text('Thanh toán qua PayOS'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivePremiumTab(bool isProActive) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [MoreJobColors.navy, Color(0xFF1D4F91)],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.workspace_premium,
                      color: MoreJobColors.brand, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isProActive
                          ? 'Gói Student AI Pro đang hoạt động'
                          : 'Trải nghiệm Phân tích Độ khớp CV - JD bằng AI',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _subscription != null
                    ? 'Gói: ${_subscription!['planCode'] ?? 'STUDENT_AI_PRO'} • Hết hạn: ${_subscription!['expiresAt'] ?? _subscription!['endDate'] ?? 'Đang kích hoạt'}'
                    : 'Chọn bất kỳ tin tuyển dụng nào bên dưới để AI chấm điểm độ tương thích với hồ sơ sinh viên của bạn.',
                style: const TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chấm điểm Độ khớp CV - JD (AI Job Match)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  isExpanded: true,
                  initialValue: _selectedJobIdForAi,
                  decoration: const InputDecoration(
                    labelText: 'Chọn vị trí tuyển dụng cần phân tích',
                  ),
                  items: _jobs.map((j) {
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
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedJobIdForAi = v),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _runAiJobMatchAnalysis,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Phân tích độ tương thích ngay'),
                  ),
                ),
                if (_jobMatchAnalysis != null) ...[
                  const Divider(height: 24),
                  Row(
                    children: [
                      StatusPill(
                        label:
                            'Độ khớp: ${_jobMatchAnalysis!['matchScore'] ?? _jobMatchAnalysis!['score'] ?? 85}%',
                        color: MoreJobColors.green,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Đánh giá từ AI Copilot',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (_jobMatchAnalysis!['summary'] ??
                            _jobMatchAnalysis!['analysis'] ??
                            _jobMatchAnalysis.toString())
                        .toString(),
                    style: const TextStyle(fontSize: 13, height: 1.45),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderTrackingTab() {
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
                  'Tra cứu trạng thái đơn hàng & Hóa đơn PayOS',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _orderIdCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Mã đơn hàng (Order ID / Order Code)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _busy
                          ? null
                          : () => _checkOrderStatus(_orderIdCtrl.text),
                      child: const Text('Kiểm tra'),
                    ),
                  ],
                ),
                if (_currentOrder != null) ...[
                  const Divider(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: MoreJobColors.brandSoft,
                      child: Icon(Icons.receipt_long, color: MoreJobColors.brand),
                    ),
                    title: Text(
                      'Đơn hàng #${_currentOrder!['orderCode'] ?? _currentOrder!['orderId'] ?? _currentOrder!['id'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      'Gói: ${_currentOrder!['planCode'] ?? 'STUDENT_AI_PRO'} • Số tiền: ${_formatVnd(_currentOrder!['amount'] ?? _currentOrder!['price'] ?? 0)}',
                    ),
                    trailing: StatusPill(
                      label:
                          (_currentOrder!['status'] ?? 'PENDING').toString(),
                      color: (_currentOrder!['status']
                                  ?.toString()
                                  .toUpperCase() ==
                              'PAID')
                          ? MoreJobColors.green
                          : MoreJobColors.brand,
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
