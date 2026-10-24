import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';

// ============================================================================
// FINANCE & INSURANCE LOGIC (exact port from more-job-fe/src/features/home/utilities/utils/finance.ts)
// ============================================================================

const List<int> regionMinimums = [5310000, 4730000, 4140000, 3700000];
const int referenceSalary = 2530000;

class FinanceSource {
  const FinanceSource(this.label, this.url);
  final String label;
  final String url;
}

const List<FinanceSource> financeSources = [
  FinanceSource(
    'Thuế tiền lương 2026',
    'https://xaydungchinhsach.chinhphu.vn/quy-dinh-moi-ve-khau-tru-thue-thu-nhap-ca-nhan-119260703150410707.htm',
  ),
  FinanceSource(
    'Giảm trừ gia cảnh',
    'https://xaydungchinhsach.chinhphu.vn/quy-dinh-giam-tru-gia-canh-trong-thue-thu-nhap-ca-nhan-119260327071750084.htm',
  ),
  FinanceSource(
    'Lương tối thiểu vùng',
    'https://baochinhphu.vn/tang-luong-toi-thieu-vung-tu-1-1-2026-102251110175033018.htm',
  ),
  FinanceSource(
    'Lương cơ sở từ 01/07/2026',
    'https://xaydungchinhsach.chinhphu.vn/tu-01-7-chinh-phu-tang-luong-co-so-119260517100243881.htm',
  ),
  FinanceSource(
    'BHXH một lần',
    'https://xaydungchinhsach.chinhphu.vn/chinh-phu-quy-dinh-chi-tiet-huong-bao-hiem-xa-hoi-mot-lan-119250628072850982.htm',
  ),
  FinanceSource(
    'Trợ cấp thất nghiệp',
    'https://xaydungchinhsach.chinhphu.vn/nhung-thay-doi-quan-trong-ve-cac-che-do-huong-bao-hiem-that-nghiep-tu-1-1-2026-119251205095855316.htm',
  ),
];

String formatVnd(num value) {
  final rounded = value.round();
  final str = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(str[i]);
  }
  return '${rounded < 0 ? '-' : ''}$buffer đ';
}

class TaxBracketPart {
  const TaxBracketPart({
    required this.bracket,
    required this.lower,
    required this.ceiling,
    required this.rate,
    required this.part,
    required this.tax,
  });
  final int bracket;
  final double lower;
  final double ceiling;
  final double rate;
  final double part;
  final double tax;
}

List<TaxBracketPart> incomeTaxParts(double taxable) {
  double previous = 0;
  final brackets = <List<double>>[
    [10000000, 0.05],
    [30000000, 0.10],
    [60000000, 0.20],
    [100000000, 0.30],
    [double.infinity, 0.35],
  ];
  final result = <TaxBracketPart>[];
  for (var i = 0; i < brackets.length; i++) {
    final ceiling = brackets[i][0];
    final rate = brackets[i][1];
    final capped = taxable < ceiling ? taxable : ceiling;
    final part = (capped - previous) > 0 ? (capped - previous) : 0.0;
    final lower = previous;
    previous = ceiling;
    result.add(
      TaxBracketPart(
        bracket: i + 1,
        lower: lower,
        ceiling: ceiling,
        rate: rate,
        part: part,
        tax: part * rate,
      ),
    );
  }
  return result;
}

double incomeTax(double taxable) {
  return incomeTaxParts(taxable).fold(0.0, (sum, part) => sum + part.tax);
}

class SalaryBreakdown {
  const SalaryBreakdown({
    required this.gross,
    required this.social,
    required this.health,
    required this.unemployment,
    required this.insurance,
    required this.deduction,
    required this.taxable,
    required this.tax,
    required this.net,
  });
  final double gross;
  final double social;
  final double health;
  final double unemployment;
  final double insurance;
  final double deduction;
  final double taxable;
  final double tax;
  final double net;
}

SalaryBreakdown salaryBreakdown(
  double gross,
  int dependents,
  int region, [
  double? insuranceSalary,
]) {
  final base = insuranceSalary != null && insuranceSalary < gross
      ? insuranceSalary
      : gross;
  final capRef = 20.0 * referenceSalary;
  final capRegion = 20.0 * regionMinimums[region.clamp(0, 3)];
  final social = (base < capRef ? base : capRef) * 0.08;
  final health = (base < capRef ? base : capRef) * 0.015;
  final unemployment = (base < capRegion ? base : capRegion) * 0.01;
  final insurance = social + health + unemployment;
  final deduction = 15500000.0 + dependents * 6200000.0;
  final taxable = (gross - insurance - deduction) > 0
      ? (gross - insurance - deduction)
      : 0.0;
  final tax = incomeTax(taxable);
  return SalaryBreakdown(
    gross: gross,
    social: social,
    health: health,
    unemployment: unemployment,
    insurance: insurance,
    deduction: deduction,
    taxable: taxable,
    tax: tax,
    net: gross - insurance - tax,
  );
}

SalaryBreakdown netToGross(
  double net,
  int dependents,
  int region, [
  double? insuranceSalary,
]) {
  double low = net;
  double high = net * 3 + 1;
  for (var i = 0; i < 80; i++) {
    final middle = (low + high) / 2;
    if (salaryBreakdown(middle, dependents, region, insuranceSalary).net <
        net) {
      low = middle;
    } else {
      high = middle;
    }
  }
  return salaryBreakdown((low + high) / 2, dependents, region, insuranceSalary);
}

class UnemploymentResult {
  const UnemploymentResult({
    required this.monthly,
    required this.duration,
    required this.total,
  });
  final double monthly;
  final int duration;
  final double total;
}

UnemploymentResult unemploymentBenefit(
  double average,
  int months,
  int region,
) {
  final duration = months < 12
      ? 0
      : (3 + ((months - 36 > 0 ? months - 36 : 0) ~/ 12)).clamp(0, 12);
  final maxMonthly = regionMinimums[region.clamp(0, 3)] * 5.0;
  final rawMonthly = average * 0.6;
  final monthly = duration > 0
      ? (rawMonthly < maxMonthly ? rawMonthly : maxMonthly)
      : 0.0;
  return UnemploymentResult(
    monthly: monthly,
    duration: duration,
    total: monthly * duration,
  );
}

double socialInsuranceBenefit(
  double average,
  int beforeMonths,
  int afterMonths,
) {
  final totalMonths = beforeMonths + afterMonths;
  if (totalMonths < 12) {
    final v1 = average * 0.22 * totalMonths;
    final v2 = average * 2.0;
    return v1 < v2 ? v1 : v2;
  }
  if (afterMonths == 0) {
    final remainder = beforeMonths % 12;
    final years =
        (beforeMonths ~/ 12) +
        (remainder == 0
            ? 0.0
            : remainder <= 6
            ? 0.5
            : 1.0);
    return average * years * 1.5;
  }
  final beforeYears = beforeMonths ~/ 12;
  final afterTotal = afterMonths + (beforeMonths % 12);
  final remainder = afterTotal % 12;
  final afterYears =
      (afterTotal ~/ 12) +
      (remainder == 0
          ? 0.0
          : remainder <= 6
          ? 0.5
          : 1.0);
  return average * (beforeYears * 1.5 + afterYears * 2.0);
}

// ============================================================================
// SCAM CHECK LOGIC (from scam-check.ts & scam-checklist.ts)
// ============================================================================

class ScamFinding {
  const ScamFinding(this.label, this.tip);
  final String label;
  final String tip;
}

final List<(RegExp, String, String)> _scamRules = [
  (
    RegExp(
      r'đặt cọc|nộp phí|phí hồ sơ|phí tuyển dụng|chuyển khoản trước|đóng phí|ứng tiền',
      caseSensitive: false,
    ),
    'Yêu cầu trả tiền trước khi được tuyển',
    'Không chuyển tiền; xác minh trực tiếp với doanh nghiệp qua kênh chính thức.',
  ),
  (
    RegExp(
      r'mã otp|mật khẩu|mã xác thực|thông tin thẻ|số thẻ ngân hàng',
      caseSensitive: false,
    ),
    'Yêu cầu thông tin tài khoản hoặc mã bảo mật',
    'Không cung cấp OTP, mật khẩu hoặc thông tin thẻ cho người tuyển dụng.',
  ),
  (
    RegExp(
      r'giữ.*(?:cccd|căn cước|giấy tờ gốc)|nộp.*(?:cccd gốc|căn cước gốc)',
      caseSensitive: false,
    ),
    'Yêu cầu giữ giấy tờ tùy thân bản gốc',
    'Tránh giao bản gốc; hỏi rõ căn cứ và nhu cầu sử dụng giấy tờ.',
  ),
  (
    RegExp(
      r'việc nhẹ lương cao|thu nhập khủng|cam kết.*thu nhập|lương.*(?:triệu\/ngày|triệu mỗi ngày)',
      caseSensitive: false,
    ),
    'Hứa hẹn thu nhập bất thường hoặc đảm bảo tuyệt đối',
    'Yêu cầu mô tả công việc, cơ chế lương và hợp đồng cụ thể.',
  ),
  (
    RegExp(
      r'telegram|tải.*apk|cài.*apk|nạp tiền|chốt đơn.*hoàn tiền',
      caseSensitive: false,
    ),
    'Kênh trao đổi hoặc nhiệm vụ cần kiểm tra thêm',
    'Telegram riêng lẻ không chứng minh lừa đảo. Không cài ứng dụng lạ hoặc nạp tiền để làm nhiệm vụ.',
  ),
  (
    RegExp(
      r'tuyển gấp.*không.*phỏng vấn|không cần.*phỏng vấn|nhận ngay.*không.*hợp đồng',
      caseSensitive: false,
    ),
    'Bỏ qua xác minh và quy trình tuyển dụng',
    'Xác minh pháp nhân, người liên hệ và địa điểm làm việc trước khi nhận việc.',
  ),
];

const List<ScamFinding> scamChecklist = [
  ScamFinding(
    'Bên tuyển dụng yêu cầu tôi trả tiền hoặc nạp tiền',
    'Tạm dừng giao dịch và xác minh qua đầu mối doanh nghiệp bạn tự tìm được.',
  ),
  ScamFinding(
    'Tôi được yêu cầu cung cấp OTP hoặc mật khẩu',
    'Không chia sẻ mã bảo mật hoặc quyền truy cập tài khoản.',
  ),
  ScamFinding(
    'Tôi bị thúc ép nhận việc hoặc chuyển tiền ngay',
    'Dành thời gian kiểm tra; không quyết định vì áp lực hoặc lời hứa giữ chỗ.',
  ),
  ScamFinding(
    'Tôi chưa xác minh được công ty và người liên hệ',
    'Đối chiếu tên pháp nhân, địa chỉ và đầu mối tuyển dụng qua website chính thức.',
  ),
];

List<ScamFinding> checkRecruitmentScam(String content) {
  return _scamRules
      .where((rule) => rule.$1.hasMatch(content))
      .map((rule) => ScamFinding(rule.$2, rule.$3))
      .toList();
}

// ============================================================================
// MBTI LOGIC (60 questions + 16 profiles from mbti-questions.ts & mbti-profiles.ts)
// ============================================================================

class MbtiQuestion {
  const MbtiQuestion({
    required this.id,
    required this.axis,
    required this.text,
    required this.reverse,
  });
  final String id;
  final String axis;
  final String text;
  final bool reverse;
}

class MbtiProfile {
  const MbtiProfile({
    required this.code,
    required this.name,
    required this.description,
    required this.strengths,
    required this.practice,
    required this.explore,
    required this.color,
  });
  final String code;
  final String name;
  final String description;
  final List<String> strengths;
  final String practice;
  final List<String> explore;
  final Color color;
}

const List<String> mbtiAxes = ['EI', 'SN', 'TF', 'JP'];
const List<String> mbtiChoices = [
  'Rất không đồng ý',
  'Không đồng ý',
  'Hơi không đồng ý',
  'Trung lập',
  'Hơi đồng ý',
  'Đồng ý',
  'Rất đồng ý',
];

const Map<String, List<String>> mbtiAxisLabels = {
  'EI': ['Hướng ngoại', 'Hướng nội'],
  'SN': ['Thực tế', 'Trực giác'],
  'TF': ['Lý trí', 'Cảm xúc'],
  'JP': ['Kế hoạch', 'Linh hoạt'],
};

const Map<String, List<(String, bool)>> _mbtiRawItems = {
  'EI': [
    (
      'Sau một buổi học dài, trò chuyện với bạn bè giúp tôi lấy lại năng lượng.',
      false,
    ),
    (
      'Tôi muốn có một khoảng yên tĩnh riêng trước khi tham gia hoạt động tiếp theo.',
      true,
    ),
    (
      'Trong buổi gặp mặt đầu tiên, tôi thường là người mở đầu cuộc trò chuyện.',
      false,
    ),
    ('Tôi thích viết ý tưởng ra trước khi trình bày với cả nhóm.', true),
    ('Tôi dễ tìm được điều để nói khi gặp một người chưa quen.', false),
    (
      'Tôi thấy một cuộc trò chuyện sâu với một người thú vị hơn nhiều cuộc trao đổi ngắn.',
      true,
    ),
    (
      'Tôi thường làm rõ suy nghĩ của mình bằng cách nói chuyện với người khác.',
      false,
    ),
    ('Sau nhiều giờ giao tiếp, tôi cần thời gian một mình để hồi phục.', true),
    (
      'Tôi thích tham gia những hoạt động có nhiều người cùng tương tác.',
      false,
    ),
    (
      'Khi có tin vui, tôi thường suy ngẫm riêng một lúc rồi mới chia sẻ.',
      true,
    ),
    ('Tôi sẵn sàng phát biểu ngay khi lớp hoặc nhóm đặt câu hỏi mở.', false),
    ('Tôi thích giữ một số trải nghiệm cá nhân cho riêng mình.', true),
    ('Tôi cảm thấy hào hứng khi được mở rộng mạng lưới quen biết.', false),
    ('Một ngày có ít cuộc gặp thường giúp tôi tập trung tốt hơn.', true),
    (
      'Trong dự án mới, tôi muốn trao đổi trực tiếp với mọi người từ sớm.',
      false,
    ),
  ],
  'SN': [
    ('Khi học một kỹ năng mới, tôi muốn xem một ví dụ thực tế trước.', false),
    (
      'Tôi hay tự hỏi một ý tưởng có thể phát triển thành những khả năng nào.',
      true,
    ),
    (
      'Tôi tin vào dữ liệu quan sát được hơn một dự đoán chưa được kiểm tra.',
      false,
    ),
    (
      'Tôi thích tìm điểm liên hệ giữa những chủ đề tưởng như không liên quan.',
      true,
    ),
    ('Khi nhận hướng dẫn, tôi chú ý đến từng bước cần thực hiện.', false),
    (
      'Tôi thấy hứng thú với việc tưởng tượng một cách làm chưa ai thử trong nhóm.',
      true,
    ),
    ('Tôi nhớ những chi tiết cụ thể của một trải nghiệm khá rõ.', false),
    (
      'Tôi thường nghĩ về ý nghĩa phía sau một sự kiện hơn những chi tiết của nó.',
      true,
    ),
    (
      'Một phương án đã được thử nghiệm khiến tôi yên tâm hơn một phương án mới.',
      false,
    ),
    (
      'Tôi thích bắt đầu từ bức tranh tổng thể rồi mới tìm hiểu từng phần.',
      true,
    ),
    (
      'Tôi muốn mục tiêu được mô tả bằng kết quả có thể quan sát hoặc đo lường.',
      false,
    ),
    (
      'Tôi thường đặt câu hỏi về cách một việc có thể khác đi trong tương lai.',
      true,
    ),
    ('Trong báo cáo, tôi quan tâm đến ví dụ và số liệu cụ thể.', false),
    (
      'Những giả thuyết và ý tưởng trừu tượng khiến tôi muốn khám phá thêm.',
      true,
    ),
    (
      'Tôi thích áp dụng kiến thức vào một vấn đề đang xảy ra trước mắt.',
      false,
    ),
  ],
  'TF': [
    (
      'Khi chọn phương án, tôi bắt đầu bằng việc so sánh các tiêu chí khách quan.',
      false,
    ),
    (
      'Tôi cân nhắc cảm nhận của những người bị ảnh hưởng trước khi chốt quyết định.',
      true,
    ),
    (
      'Tôi muốn các nguyên tắc được áp dụng nhất quán cho mọi người.',
      false,
    ),
    (
      'Khi góp ý, tôi dành thời gian tìm cách nói để người nghe cảm thấy được tôn trọng.',
      true,
    ),
    (
      'Tôi có thể thay đổi quan điểm khi một lập luận hợp lý hơn được đưa ra.',
      false,
    ),
    (
      'Tôi muốn hiểu hoàn cảnh riêng của một người trước khi đánh giá việc họ làm.',
      true,
    ),
    (
      'Trong tranh luận, tôi chú ý đến tính đúng đắn của lý lẽ hơn việc đồng thuận.',
      false,
    ),
    (
      'Giữ quan hệ tốt trong nhóm là điều tôi coi trọng khi giải quyết bất đồng.',
      true,
    ),
    (
      'Tôi thích phân tích ưu và nhược điểm trước khi làm theo cảm nhận ban đầu.',
      false,
    ),
    (
      'Tôi thường tự hỏi lựa chọn này có phù hợp với những giá trị mình tin tưởng không.',
      true,
    ),
    (
      'Khi đánh giá một sản phẩm, tôi ưu tiên chất lượng và tiêu chí đã thống nhất.',
      false,
    ),
    ('Tôi dễ nhận ra khi một quyết định khiến người khác khó xử.', true),
    (
      'Tôi muốn biết nguyên nhân và bằng chứng trước khi kết luận ai đúng.',
      false,
    ),
    (
      'Tôi thấy động lực của người thực hiện cũng quan trọng khi đánh giá kết quả.',
      true,
    ),
    (
      'Tôi chấp nhận một góp ý thẳng thắn nếu nó giúp công việc tốt hơn.',
      false,
    ),
  ],
  'JP': [
    (
      'Trước một tuần bận rộn, tôi thường sắp xếp lịch và các việc ưu tiên.',
      false,
    ),
    ('Tôi thích giữ một vài lựa chọn mở để thích nghi với tình hình.', true),
    (
      'Tôi thấy thoải mái khi thời hạn và trách nhiệm đã được thống nhất rõ.',
      false,
    ),
    (
      'Một thay đổi bất ngờ đôi khi khiến tôi hào hứng thử cách mới.',
      true,
    ),
    (
      'Tôi thường hoàn thành phần việc quan trọng trước khi nghỉ ngơi.',
      false,
    ),
    (
      'Tôi thích khám phá thêm thông tin trước khi chốt một kế hoạch.',
      true,
    ),
    ('Danh sách những việc cần làm giúp tôi bớt căng thẳng.', false),
    ('Tôi dễ điều chỉnh lịch khi xuất hiện một cơ hội thú vị.', true),
    (
      'Tôi muốn một cuộc họp kết thúc bằng các quyết định và bước tiếp theo cụ thể.',
      false,
    ),
    (
      'Tôi thích có không gian để thay đổi cách thực hiện trong quá trình làm việc.',
      true,
    ),
    ('Tôi thường chia một nhiệm vụ lớn thành các mốc nhỏ từ đầu.', false),
    (
      'Tôi không ngại bắt đầu khi chưa có kế hoạch chi tiết cho toàn bộ công việc.',
      true,
    ),
    ('Tôi thích chuẩn bị trước hơn xử lý mọi việc vào phút cuối.', false),
    (
      'Tôi có thể tận hưởng một chuyến đi không có lịch trình quá chặt.',
      true,
    ),
    (
      'Khi một việc còn dang dở, tôi muốn sớm chốt để chuyển sang việc tiếp theo.',
      false,
    ),
  ],
};

final List<MbtiQuestion> mbtiQuestions = [
  for (var i = 0; i < 15; i++)
    for (final axis in mbtiAxes)
      MbtiQuestion(
        id: '$axis-${i + 1}',
        axis: axis,
        text: _mbtiRawItems[axis]![i].$1,
        reverse: _mbtiRawItems[axis]![i].$2,
      ),
];

class MbtiAxisScore {
  const MbtiAxisScore({
    required this.axis,
    required this.percent,
    required this.letter,
    required this.balanced,
  });
  final String axis;
  final int percent;
  final String letter;
  final bool balanced;
}

class MbtiScoreResult {
  const MbtiScoreResult({required this.axes, required this.code});
  final List<MbtiAxisScore> axes;
  final String code;
}

MbtiScoreResult scoreMbti(Map<String, int> answers) {
  final axes = mbtiAxes.map((axis) {
    final qs = mbtiQuestions.where((q) => q.axis == axis).toList();
    final sum = qs.fold<int>(
      0,
      (total, q) =>
          total + ((answers[q.id] ?? 3) - 3) * (q.reverse ? -1 : 1),
    );
    final percent = (50 + (sum / (qs.length * 3)) * 50).round();
    final letter = sum == 0
        ? 'X'
        : sum > 0
        ? axis[0]
        : axis[1];
    return MbtiAxisScore(
      axis: axis,
      percent: percent,
      letter: letter,
      balanced: sum == 0,
    );
  }).toList();
  return MbtiScoreResult(
    axes: axes,
    code: axes.map((a) => a.letter).join(),
  );
}

const List<MbtiProfile> mbtiProfiles = [
  MbtiProfile(
    code: 'ISTJ',
    name: 'Người giữ cam kết',
    description:
        'Thích sự rõ ràng, chú ý chi tiết và bền bỉ hoàn thành điều đã nhận.',
    strengths: [
      'Theo sát trách nhiệm',
      'Tổ chức dữ kiện',
      'Làm việc nhất quán',
    ],
    practice:
        'Thử một cách làm mới ở quy mô nhỏ trước khi đánh giá toàn bộ phương án.',
    explore: ['Vận hành', 'Kiểm soát chất lượng', 'Kế toán'],
    color: Color(0xFFD9E9BC),
  ),
  MbtiProfile(
    code: 'ISFJ',
    name: 'Người đồng hành',
    description:
        'Quan tâm nhu cầu của người khác và thích tạo nên một môi trường đáng tin cậy.',
    strengths: ['Lắng nghe', 'Chăm sóc chi tiết', 'Hỗ trợ kiên nhẫn'],
    practice:
        'Nói rõ giới hạn thời gian và nhu cầu cá nhân khi giúp đỡ người khác.',
    explore: ['Chăm sóc khách hàng', 'Giáo dục', 'Hành chính'],
    color: Color(0xFFFFE1D0),
  ),
  MbtiProfile(
    code: 'INFJ',
    name: 'Người tìm ý nghĩa',
    description:
        'Thích nhìn sâu vào động lực và kết nối công việc với điều mình coi trọng.',
    strengths: ['Nhìn bức tranh dài hạn', 'Hiểu cảm nhận', 'Theo đuổi giá trị'],
    practice:
        'Chuyển một mục tiêu lớn thành một bước có thể thử trong tuần này.',
    explore: ['Nghiên cứu người dùng', 'Nội dung', 'Phát triển cộng đồng'],
    color: Color(0xFFFFE3A1),
  ),
  MbtiProfile(
    code: 'INTJ',
    name: 'Người vạch chiến lược',
    description:
        'Hứng thú với hệ thống và cách cải thiện chúng theo một định hướng dài hạn.',
    strengths: ['Tư duy hệ thống', 'Lập chiến lược', 'Tự học độc lập'],
    practice:
        'Chia sẻ cách bạn đi đến kết luận và mời nhóm phản hồi sớm.',
    explore: ['Phân tích dữ liệu', 'Công nghệ', 'Chiến lược sản phẩm'],
    color: Color(0xFFD3DFFF),
  ),
  MbtiProfile(
    code: 'ISTP',
    name: 'Người thử giải pháp',
    description:
        'Thích quan sát cách mọi thứ hoạt động và giải quyết vấn đề bằng thực hành.',
    strengths: ['Xử lý tình huống', 'Quan sát thực tế', 'Thử nghiệm'],
    practice:
        'Ghi lại quy trình để người khác có thể hiểu và tiếp tục công việc.',
    explore: ['Kỹ thuật', 'Phát triển phần mềm', 'Thiết kế sản phẩm'],
    color: Color(0xFFFFD1A4),
  ),
  MbtiProfile(
    code: 'ISFP',
    name: 'Người tạo dấu ấn',
    description:
        'Chú ý trải nghiệm, cảm nhận riêng và thích thể hiện qua những việc cụ thể.',
    strengths: ['Cảm nhận thẩm mỹ', 'Linh hoạt', 'Quan tâm trải nghiệm'],
    practice:
        'Đặt vài mốc kiểm tra để ý tưởng sáng tạo đi cùng tiến độ thực hiện.',
    explore: ['Thiết kế', 'Sáng tạo nội dung', 'Dịch vụ'],
    color: Color(0xFFC9F0DA),
  ),
  MbtiProfile(
    code: 'INFP',
    name: 'Người nuôi ý tưởng',
    description:
        'Thích khám phá khả năng mới và làm những điều phù hợp với giá trị cá nhân.',
    strengths: ['Tưởng tượng', 'Đồng cảm', 'Nhìn nhiều góc độ'],
    practice:
        'Chọn một ý tưởng và thử một phiên bản nhỏ thay vì chờ phương án hoàn hảo.',
    explore: ['Viết', 'Thiết kế trải nghiệm', 'Dự án xã hội'],
    color: Color(0xFFF2D2FC),
  ),
  MbtiProfile(
    code: 'INTP',
    name: 'Người đặt câu hỏi',
    description:
        'Tò mò về nguyên lý và thích phân tích một vấn đề từ nhiều cách tiếp cận.',
    strengths: ['Phân tích logic', 'Tìm quy luật', 'Khám phá độc lập'],
    practice:
        'Đặt thời điểm dừng phân tích và trình bày một kết luận có thể hành động.',
    explore: ['Nghiên cứu', 'Lập trình', 'Phân tích hệ thống'],
    color: Color(0xFFDCE3F0),
  ),
  MbtiProfile(
    code: 'ESTP',
    name: 'Người nắm thời điểm',
    description:
        'Nhanh nhạy trước tình huống thực tế và thích học qua việc trực tiếp tham gia.',
    strengths: ['Phản ứng linh hoạt', 'Giao tiếp trực tiếp', 'Tạo hành động'],
    practice:
        'Dành một nhịp xem xét rủi ro và tác động dài hạn trước khi bắt đầu.',
    explore: ['Kinh doanh', 'Sự kiện', 'Vận hành thực địa'],
    color: Color(0xFFFFC9B8),
  ),
  MbtiProfile(
    code: 'ESFP',
    name: 'Người lan năng lượng',
    description:
        'Thích tương tác, trải nghiệm sinh động và tạo không khí tích cực cho mọi người.',
    strengths: ['Kết nối', 'Thích nghi', 'Truyền năng lượng'],
    practice:
        'Dùng lịch nhắc việc để giữ tiến độ khi có nhiều hoạt động hấp dẫn.',
    explore: ['Truyền thông', 'Dịch vụ', 'Tổ chức sự kiện'],
    color: Color(0xFFFFE1B5),
  ),
  MbtiProfile(
    code: 'ENFP',
    name: 'Người mở khả năng',
    description:
        'Hào hứng với các ý tưởng mới và những kết nối giúp mọi người cùng phát triển.',
    strengths: ['Nảy ý tưởng', 'Khích lệ', 'Kết nối chủ đề'],
    practice:
        'Giới hạn số việc đang làm và hoàn thành một thử nghiệm trước khi mở thêm.',
    explore: ['Marketing', 'Sáng tạo', 'Phát triển cộng đồng'],
    color: Color(0xFFF9DBBB),
  ),
  MbtiProfile(
    code: 'ENTP',
    name: 'Người đổi góc nhìn',
    description:
        'Thích thử thách giả định và tìm một cách giải quyết khác với lối quen thuộc.',
    strengths: ['Đặt câu hỏi', 'Tư duy linh hoạt', 'Đề xuất phương án'],
    practice:
        'Khi phản biện, làm rõ mục đích và ghi nhận những phần bạn đồng ý.',
    explore: ['Khởi nghiệp', 'Sản phẩm', 'Tư vấn'],
    color: Color(0xFFD9CAFF),
  ),
  MbtiProfile(
    code: 'ESTJ',
    name: 'Người tổ chức việc',
    description:
        'Thích mục tiêu cụ thể, phân công rõ ràng và phối hợp để hoàn thành công việc.',
    strengths: ['Điều phối', 'Quyết đoán', 'Theo dõi kết quả'],
    practice:
        'Hỏi nhóm về khó khăn và để khoảng linh hoạt trong kế hoạch.',
    explore: ['Quản lý vận hành', 'Dự án', 'Logistics'],
    color: Color(0xFFCCE5EB),
  ),
  MbtiProfile(
    code: 'ESFJ',
    name: 'Người gắn kết nhóm',
    description:
        'Quan tâm bầu không khí chung và thích giúp mọi người phối hợp thuận lợi.',
    strengths: ['Chăm sóc quan hệ', 'Phối hợp', 'Theo sát nhu cầu'],
    practice:
        'Phân biệt điều bạn muốn với kỳ vọng của người khác trước khi nhận thêm việc.',
    explore: ['Nhân sự', 'Dịch vụ khách hàng', 'Điều phối'],
    color: Color(0xFFFFCEDB),
  ),
  MbtiProfile(
    code: 'ENFJ',
    name: 'Người khích lệ',
    description:
        'Thích giúp mọi người nhìn thấy khả năng của mình và cùng hướng tới mục tiêu.',
    strengths: ['Truyền đạt', 'Hướng dẫn', 'Thấu hiểu nhóm'],
    practice:
        'Kiểm tra giả định về nhu cầu của người khác bằng một câu hỏi trực tiếp.',
    explore: ['Đào tạo', 'Nhân sự', 'Truyền thông'],
    color: Color(0xFFD6EDCB),
  ),
  MbtiProfile(
    code: 'ENTJ',
    name: 'Người dẫn hướng',
    description:
        'Hướng tới kết quả dài hạn và thích tổ chức nguồn lực để biến kế hoạch thành hành động.',
    strengths: [
      'Xác định mục tiêu',
      'Ra quyết định',
      'Tổ chức nguồn lực',
    ],
    practice:
        'Mời ý kiến khác biệt trước khi quyết định và quan tâm nhịp làm việc của nhóm.',
    explore: ['Quản lý dự án', 'Chiến lược', 'Phát triển kinh doanh'],
    color: Color(0xFFD4DDF6),
  ),
];

// ============================================================================
// DISC & MI QUIZZES (from quiz-data.ts & quiz-questions.ts)
// ============================================================================

class QuizQuestion {
  const QuizQuestion(this.group, this.text, {this.reverse = false});
  final String group;
  final String text;
  final bool reverse;
}

class QuizDefinition {
  const QuizDefinition({
    required this.groups,
    required this.questions,
    required this.tips,
  });
  final Map<String, String> groups;
  final List<QuizQuestion> questions;
  final Map<String, String> tips;
}

List<QuizQuestion> _makeQuizQuestions(String group, List<String> texts) =>
    texts.map((t) => QuizQuestion(group, t)).toList();

final QuizDefinition discQuiz = QuizDefinition(
  groups: const {
    'D': 'D · Chủ động',
    'I': 'I · Kết nối',
    'S': 'S · Ổn định',
    'C': 'C · Cẩn trọng',
  },
  questions: [
    ..._makeQuizQuestions('D', [
      'Tôi sẵn sàng đứng ra quyết định khi nhóm gặp bế tắc.',
      'Tôi thích mục tiêu khó và kết quả rõ ràng.',
      'Tôi trao đổi thẳng thắn khi cần giải quyết vấn đề.',
    ]),
    ..._makeQuizQuestions('I', [
      'Tôi dễ tạo không khí tích cực trong nhóm.',
      'Tôi thích thuyết trình và chia sẻ ý tưởng.',
      'Tôi thường kết nối mọi người với nhau.',
    ]),
    ..._makeQuizQuestions('S', [
      'Tôi kiên nhẫn lắng nghe người khác.',
      'Tôi thích hỗ trợ nhóm làm việc đều đặn.',
      'Tôi thấy thoải mái với nhịp làm việc ổn định.',
    ]),
    ..._makeQuizQuestions('C', [
      'Tôi kiểm tra kỹ thông tin trước khi kết luận.',
      'Tôi thích tiêu chuẩn và quy trình rõ ràng.',
      'Tôi chú ý chất lượng và độ chính xác của sản phẩm.',
    ]),
    ..._makeQuizQuestions('D', [
      'Tôi chia mục tiêu lớn thành những việc cần thực hiện.',
      'Tôi chịu trách nhiệm về quyết định của mình.',
      'Khi kế hoạch gặp trở ngại, tôi nhanh chóng đề xuất hướng khác.',
      'Tôi nêu rõ kết quả mong đợi trước khi giao việc.',
      'Tôi nói không khi một yêu cầu khiến nhóm lệch mục tiêu.',
      'Tôi muốn thử phương án mới để cải thiện kết quả.',
      'Tôi ưu tiên giải quyết vấn đề quan trọng trước các việc dễ làm.',
    ]),
    ..._makeQuizQuestions('I', [
      'Tôi dễ bắt đầu trò chuyện với đồng nghiệp mới.',
      'Tôi khuyến khích người khác chia sẻ ý kiến.',
      'Tôi dùng ví dụ sinh động để giải thích ý tưởng.',
      'Tôi hào hứng khi được làm việc với nhiều người.',
      'Tôi thường ghi nhận thành công nhỏ của đồng đội.',
      'Tôi dễ truyền sự hào hứng về một dự án.',
      'Tôi thích xây dựng quan hệ trước khi bàn công việc.',
    ]),
    ..._makeQuizQuestions('S', [
      'Tôi giúp người mới làm quen với công việc mà không thúc ép.',
      'Tôi giữ bình tĩnh khi đồng đội cần thêm thời gian.',
      'Tôi hoàn thành đều đặn các cam kết đã nhận.',
      'Tôi trao đổi để cả nhóm cùng hiểu một thay đổi.',
      'Tôi tìm hiểu nhu cầu của người cùng làm việc.',
      'Tôi hài lòng khi hỗ trợ người khác hoàn thành việc.',
      'Tôi thích môi trường nơi mọi người tin cậy nhau.',
    ]),
    ..._makeQuizQuestions('C', [
      'Tôi đối chiếu số liệu với nguồn trước khi dùng trong báo cáo.',
      'Tôi hỏi lại khi tiêu chí hoàn thành chưa rõ.',
      'Tôi ghi chú các bước quan trọng để tránh bỏ sót.',
      'Tôi xem xét rủi ro trước khi chọn phương án.',
      'Tôi thích có bằng chứng cho một nhận định.',
      'Tôi rà soát lỗi trước khi bàn giao công việc.',
      'Tôi quan tâm độ nhất quán của quy trình.',
    ]),
  ],
  tips: const {
    'D':
        'Phát huy khả năng chủ động; dành thêm thời gian lắng nghe trước khi chốt phương án.',
    'I':
        'Phát huy kết nối; dùng danh sách việc và thời hạn để theo sát ý tưởng.',
    'S':
        'Phát huy sự kiên nhẫn; tập nói rõ nhu cầu và chủ động thử thay đổi nhỏ.',
    'C':
        'Phát huy độ chính xác; phân biệt việc cần hoàn hảo với việc cần hoàn thành.',
  },
);

final QuizDefinition miQuiz = QuizDefinition(
  groups: const {
    'language': 'Ngôn ngữ',
    'logic': 'Logic & số học',
    'visual': 'Không gian',
    'body': 'Vận động',
    'music': 'Âm nhạc',
    'social': 'Giao tiếp',
    'self': 'Nội tâm',
    'nature': 'Thiên nhiên',
  },
  questions: [
    ..._makeQuizQuestions('language', [
      'Tôi thích viết hoặc kể chuyện.',
      'Tôi dễ diễn đạt một ý tưởng bằng lời.',
      'Tôi hứng thú với việc học từ ngữ mới.',
    ]),
    ..._makeQuizQuestions('logic', [
      'Tôi thích tìm quy luật trong dữ liệu.',
      'Tôi thích giải câu đố logic.',
      'Tôi muốn hiểu nguyên nhân của một vấn đề.',
    ]),
    ..._makeQuizQuestions('visual', [
      'Tôi dễ hình dung bố cục trong đầu.',
      'Tôi thích vẽ hoặc thiết kế.',
      'Sơ đồ giúp tôi học nhanh hơn.',
    ]),
    ..._makeQuizQuestions('body', [
      'Tôi học tốt khi thực hành trực tiếp.',
      'Tôi thích hoạt động vận động.',
      'Tôi dễ phối hợp tay và mắt khi làm việc.',
    ]),
    ..._makeQuizQuestions('music', [
      'Tôi nhận ra nhịp điệu dễ dàng.',
      'Tôi thích hát hoặc chơi nhạc cụ.',
      'Tôi thường nhớ giai điệu sau khi nghe.',
    ]),
    ..._makeQuizQuestions('social', [
      'Tôi nhận ra khi người khác cần hỗ trợ.',
      'Tôi thích học qua trao đổi nhóm.',
      'Tôi có thể giúp hòa giải bất đồng.',
    ]),
    ..._makeQuizQuestions('self', [
      'Tôi thường nhìn lại cảm xúc và lựa chọn của mình.',
      'Tôi biết điều gì giúp mình có động lực.',
      'Tôi thích đặt mục tiêu phát triển cá nhân.',
    ]),
    ..._makeQuizQuestions('nature', [
      'Tôi chú ý các đặc điểm của cây và động vật.',
      'Tôi thích khám phá môi trường tự nhiên.',
      'Tôi hứng thú với việc phân loại và quan sát tự nhiên.',
    ]),
    ..._makeQuizQuestions('language', [
      'Tôi thích tóm tắt bài học bằng lời của mình.',
      'Tôi thấy thú vị khi trao đổi về ý nghĩa của một câu nói.',
      'Tôi đọc thêm để tìm cách diễn đạt rõ ràng hơn.',
    ]),
    ..._makeQuizQuestions('logic', [
      'Tôi thích chia vấn đề thành các bước có thể kiểm tra.',
      'Tôi hứng thú so sánh số liệu để tìm khác biệt.',
      'Tôi hỏi điều gì sẽ xảy ra nếu đổi một điều kiện.',
    ]),
    ..._makeQuizQuestions('visual', [
      'Tôi dùng màu sắc để phân nhóm thông tin.',
      'Tôi thích sắp xếp hình ảnh thành một câu chuyện.',
      'Tôi phác thảo trước khi giải thích một bố cục.',
    ]),
    ..._makeQuizQuestions('body', [
      'Tôi nhớ bài học rõ hơn sau khi tự thao tác.',
      'Tôi thích làm mô hình hoặc lắp ráp vật dụng.',
      'Tôi thích hoạt động cần luyện phối hợp động tác.',
    ]),
    ..._makeQuizQuestions('music', [
      'Tôi thích nhận biết sự khác nhau giữa các âm thanh.',
      'Tôi dùng nhịp để nhớ một chuỗi thông tin.',
      'Tôi thích khám phá cảm xúc mà bản nhạc tạo ra.',
    ]),
    ..._makeQuizQuestions('social', [
      'Tôi hứng thú tìm hiểu cách nhìn khác với mình.',
      'Tôi thích cùng người khác giải quyết nhiệm vụ.',
      'Tôi hỏi thêm để hiểu điều người đối diện muốn nói.',
    ]),
    ..._makeQuizQuestions('self', [
      'Tôi dành thời gian một mình để suy ngẫm.',
      'Tôi nhận ra tình huống làm mình mất tập trung.',
      'Tôi điều chỉnh kế hoạch sau khi nhìn lại trải nghiệm.',
    ]),
    ..._makeQuizQuestions('nature', [
      'Tôi ghi lại thay đổi trong môi trường quanh mình.',
      'Tôi hứng thú với mối liên hệ giữa các sinh vật.',
      'Tôi thích so sánh và phân loại vật thể tự nhiên.',
    ]),
  ],
  tips: const {
    'language': 'Thử viết nhật ký học tập hoặc trình bày ý tưởng.',
    'logic': 'Thử phân tích dữ liệu hoặc giải một bài toán thực tế.',
    'visual': 'Dùng sơ đồ tư duy và bản phác thảo khi học.',
    'body': 'Kết hợp bài học với thực hành và mô hình.',
    'music': 'Thử ghi nhớ qua nhịp điệu hoặc âm thanh.',
    'social': 'Thử học nhóm và hướng dẫn người khác.',
    'self': 'Ghi lại mục tiêu và phản hồi sau mỗi trải nghiệm.',
    'nature': 'Thử một dự án quan sát hoặc tìm hiểu môi trường.',
  },
);

class QuizScoreItem {
  const QuizScoreItem({
    required this.group,
    required this.label,
    required this.mean,
    required this.percent,
    required this.tip,
  });
  final String group;
  final String label;
  final double mean;
  final int percent;
  final String tip;
}

List<QuizScoreItem> scoreQuiz(QuizDefinition quiz, List<int> answers) {
  return quiz.groups.entries.map((entry) {
    final group = entry.key;
    final label = entry.value;
    final values = <int>[];
    for (var i = 0; i < quiz.questions.length; i++) {
      final q = quiz.questions[i];
      if (q.group == group) {
        final ans = i < answers.length ? answers[i] : 3;
        values.add(q.reverse ? 6 - ans : ans);
      }
    }
    final mean = values.isEmpty
        ? 3.0
        : values.reduce((a, b) => a + b) / values.length;
    return QuizScoreItem(
      group: group,
      label: label,
      mean: mean,
      percent: (((mean - 1) / 4) * 100).round(),
      tip: quiz.tips[group] ?? '',
    );
  }).toList();
}

// ============================================================================
// BANK CV LOGIC (from bank-cv.ts)
// ============================================================================

Map<String, String> parseBankCvText(String content) {
  final sections = <String, String>{};
  String current = 'experience';
  final patterns = <(String, RegExp)>[
    (
      'objective',
      RegExp(
        r'^(mục tiêu(?: nghề nghiệp)?|objective|summary)\s*[:：]?$',
        caseSensitive: false,
      ),
    ),
    ('education', RegExp(r'^(học vấn|education)\s*[:：]?$', caseSensitive: false)),
    (
      'experience',
      RegExp(
        r'^(kinh nghiệm(?: làm việc)?|dự án|experience|projects)\s*[:：]?$',
        caseSensitive: false,
      ),
    ),
    ('skills', RegExp(r'^(kỹ năng|skills)\s*[:：]?$', caseSensitive: false)),
    (
      'certificates',
      RegExp(
        r'^(chứng chỉ|certifications|certificates)\s*[:：]?$',
        caseSensitive: false,
      ),
    ),
  ];
  for (final raw in content.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final matched = patterns.where((p) => p.$2.hasMatch(line)).firstOrNull;
    if (matched != null) {
      current = matched.$1;
      continue;
    }
    final existing = sections[current];
    sections[current] = existing == null || existing.isEmpty
        ? line
        : '$existing\n$line';
  }
  return sections;
}

// ============================================================================
// UTILITIES UI PAGES
// ============================================================================

class UtilityMeta {
  const UtilityMeta({
    required this.id,
    required this.label,
    required this.category,
    required this.description,
    required this.icon,
  });
  final String id;
  final String label;
  final String category;
  final String description;
  final IconData icon;
}

const List<UtilityMeta> utilityTools = [
  UtilityMeta(
    id: 'mbti',
    label: 'Trắc nghiệm tính cách MBTI',
    category: 'Khám phá bản thân',
    description:
        'Khám phá xu hướng giao tiếp, tiếp nhận thông tin và ra quyết định.',
    icon: Icons.psychology_outlined,
  ),
  UtilityMeta(
    id: 'disc',
    label: 'Trắc nghiệm thiên hướng tính cách DISC',
    category: 'Khám phá bản thân',
    description: 'Hiểu phong cách làm việc và cách bạn phối hợp với đồng đội.',
    icon: Icons.fingerprint,
  ),
  UtilityMeta(
    id: 'mi',
    label: 'Trắc nghiệm đa trí thông minh MI',
    category: 'Khám phá bản thân',
    description: 'Nhận diện những lĩnh vực bạn thích học và phát triển.',
    icon: Icons.lightbulb_outline,
  ),
  UtilityMeta(
    id: 'gross-net',
    label: 'Tính lương Gross - Net',
    category: 'Lương & bảo hiểm',
    description: 'Quy đổi hai chiều với bảng tách thuế và các khoản bảo hiểm.',
    icon: Icons.account_balance_wallet_outlined,
  ),
  UtilityMeta(
    id: 'income-tax',
    label: 'Tính thuế thu nhập cá nhân',
    category: 'Lương & bảo hiểm',
    description: 'Ước tính thuế tiền lương theo biểu thuế năm 2026.',
    icon: Icons.receipt_long_outlined,
  ),
  UtilityMeta(
    id: 'social-insurance',
    label: 'Tính bảo hiểm xã hội một lần',
    category: 'Lương & bảo hiểm',
    description:
        'Ước tính khoản hưởng theo thời gian đóng và lương bình quân.',
    icon: Icons.savings_outlined,
  ),
  UtilityMeta(
    id: 'unemployment',
    label: 'Tính bảo hiểm thất nghiệp',
    category: 'Lương & bảo hiểm',
    description: 'Ước tính mức hưởng hằng tháng và số tháng trợ cấp.',
    icon: Icons.verified_user_outlined,
  ),
  UtilityMeta(
    id: 'scam-check',
    label: 'Check chống lừa đảo tuyển dụng',
    category: 'Ứng tuyển an toàn',
    description:
        'Rà soát những dấu hiệu đáng chú ý trong nội dung tuyển dụng.',
    icon: Icons.gpp_maybe_outlined,
  ),
  UtilityMeta(
    id: 'bank-cv',
    label: 'Chuyển đổi CV liên ngân hàng',
    category: 'Ứng tuyển an toàn',
    description:
        'Chuẩn hóa nội dung thành CV ứng tuyển ngân hàng, tải và xem trước.',
    icon: Icons.description_outlined,
  ),
];

class UtilitiesHubPage extends StatelessWidget {
  const UtilitiesHubPage({super.key, this.embedded = false});
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final categories = const [
      'Khám phá bản thân',
      'Lương & bảo hiểm',
      'Ứng tuyển an toàn',
    ];
    final body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [MoreJobColors.accent, Color(0xFF1A4B84)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StatusPill(
                label: 'MOREJOB · CÔNG CỤ NGHỀ NGHIỆP',
                background: Color(0x33FFFFFF),
                foreground: Colors.white,
                icon: Icons.auto_awesome,
              ),
              const SizedBox(height: 12),
              const Text(
                'Hiểu bản thân. Chủ động sự nghiệp.',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Từ khám phá tính cách đến tính lương và chuẩn bị hồ sơ — các tiện ích dành cho hành trình đi làm của bạn.',
                style: TextStyle(color: Color(0xFFDCE9FF), fontSize: 13.5),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  StatusPill(
                    label: 'Miễn phí',
                    background: Color(0x26FFFFFF),
                    foreground: Colors.white,
                  ),
                  StatusPill(
                    label: 'Không cần đăng nhập',
                    background: Color(0x26FFFFFF),
                    foreground: Colors.white,
                  ),
                  StatusPill(
                    label: 'Xử lý ngay trên thiết bị',
                    background: Color(0x26FFFFFF),
                    foreground: Colors.white,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        for (final category in categories) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 6),
            child: Text(
              category,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ...utilityTools
              .where((tool) => tool.category == category)
              .map(
                (tool) => Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: MoreJobColors.brandSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(tool.icon, color: MoreJobColors.brand),
                    ),
                    title: Text(
                      tool.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(tool.description),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 15,
                      color: MoreJobColors.brand,
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UtilityDetailPage(tool: tool),
                      ),
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 10),
        ],
      ],
    );

    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Tiện ích nghề nghiệp')),
      body: body,
    );
  }
}

class UtilityDetailPage extends StatelessWidget {
  const UtilityDetailPage({super.key, required this.tool});
  final UtilityMeta tool;

  @override
  Widget build(BuildContext context) {
    Widget content;
    switch (tool.id) {
      case 'mbti':
        content = const MbtiToolView();
        break;
      case 'disc':
        content = const PersonalityQuizView(type: 'disc');
        break;
      case 'mi':
        content = const PersonalityQuizView(type: 'mi');
        break;
      case 'gross-net':
        content = const SalaryCalculatorView(taxOnly: false);
        break;
      case 'income-tax':
        content = const SalaryCalculatorView(taxOnly: true);
        break;
      case 'social-insurance':
        content = const InsuranceCalculatorView(unemployment: false);
        break;
      case 'unemployment':
        content = const InsuranceCalculatorView(unemployment: true);
        break;
      case 'scam-check':
        content = const ScamCheckToolView();
        break;
      case 'bank-cv':
      default:
        content = const BankCvToolView();
        break;
    }

    return Scaffold(
      appBar: AppBar(title: Text(tool.label)),
      body: content,
    );
  }
}

// ============================================================================
// 1. MBTI TOOL VIEW
// ============================================================================

class MbtiToolView extends StatefulWidget {
  const MbtiToolView({super.key});
  @override
  State<MbtiToolView> createState() => _MbtiToolViewState();
}

class _MbtiToolViewState extends State<MbtiToolView> {
  final Map<String, int> answers = {
    for (final q in mbtiQuestions) q.id: 3,
  };
  int pageIndex = 0;
  bool showResult = false;
  static const int pageSize = 10;

  @override
  Widget build(BuildContext context) {
    if (showResult) {
      final scored = scoreMbti(answers);
      final matched = mbtiProfiles.where((p) => p.code == scored.code).firstOrNull ??
          mbtiProfiles.first;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: matched.color.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: MoreJobColors.brandBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusPill(label: 'KẾT QUẢ MBTI · ${scored.code}'),
                const SizedBox(height: 10),
                Text(
                  '${scored.code} — ${matched.name}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(matched.description),
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
                    '4 Cặp xu hướng tính cách',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  for (final axis in scored.axes) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${mbtiAxisLabels[axis.axis]![0]} (${axis.axis[0]})',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${axis.percent}% · ${axis.letter}',
                          style: const TextStyle(
                            color: MoreJobColors.brandStrong,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${mbtiAxisLabels[axis.axis]![1]} (${axis.axis[1]})',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: axis.percent / 100.0,
                        minHeight: 10,
                        backgroundColor: MoreJobColors.blueSoft,
                        color: MoreJobColors.brand,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Điểm mạnh nổi bật',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: matched.strengths
                        .map((s) => StatusPill(label: s))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Gợi ý rèn luyện',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(matched.practice),
                  const SizedBox(height: 16),
                  const Text(
                    'Lĩnh vực nghề nghiệp gợi ý khám phá',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: matched.explore
                        .map(
                          (e) => StatusPill(
                            label: e,
                            background: MoreJobColors.blueSoft,
                            foreground: MoreJobColors.bluePrimary,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => showResult = false),
                  child: const Text('Sửa câu trả lời'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => setState(() {
                    for (final q in mbtiQuestions) {
                      answers[q.id] = 3;
                    }
                    pageIndex = 0;
                    showResult = false;
                  }),
                  child: const Text('Làm lại từ đầu'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    final totalPages = (mbtiQuestions.length / pageSize).ceil();
    final start = pageIndex * pageSize;
    final end = (start + pageSize).clamp(0, mbtiQuestions.length);
    final pageQuestions = mbtiQuestions.sublist(start, end);

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phần ${pageIndex + 1} / $totalPages (${mbtiQuestions.length} câu)',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: (pageIndex + 1) / totalPages,
                      backgroundColor: MoreJobColors.border,
                      color: MoreJobColors.brand,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => setState(() => showResult = true),
                child: const Text('Xem kết quả ngay'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pageQuestions.length,
            itemBuilder: (context, idx) {
              final q = pageQuestions[idx];
              final currentVal = answers[q.id] ?? 3;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Câu ${start + idx + 1}. ${q.text}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Slider(
                        value: currentVal.toDouble(),
                        min: 0,
                        max: 6,
                        divisions: 6,
                        activeColor: MoreJobColors.brand,
                        label: mbtiChoices[currentVal],
                        onChanged: (v) =>
                            setState(() => answers[q.id] = v.round()),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          mbtiChoices[currentVal],
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
              );
            },
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (pageIndex > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => pageIndex--),
                    child: const Text('Trang trước'),
                  ),
                ),
              if (pageIndex > 0) const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    if (pageIndex + 1 < totalPages) {
                      setState(() => pageIndex++);
                    } else {
                      setState(() => showResult = true);
                    }
                  },
                  child: Text(
                    pageIndex + 1 < totalPages
                        ? 'Tiếp theo'
                        : 'Hoàn tất & Xem kết quả',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 2. DISC & MI QUIZ VIEW
// ============================================================================

class PersonalityQuizView extends StatefulWidget {
  const PersonalityQuizView({super.key, required this.type});
  final String type;

  @override
  State<PersonalityQuizView> createState() => _PersonalityQuizViewState();
}

class _PersonalityQuizViewState extends State<PersonalityQuizView> {
  late final QuizDefinition quiz = widget.type == 'disc' ? discQuiz : miQuiz;
  late List<int> answers = List<int>.filled(quiz.questions.length, 3);
  bool showResult = false;

  @override
  Widget build(BuildContext context) {
    if (showResult) {
      final scores = scoreQuiz(quiz, answers)
        ..sort((a, b) => b.percent.compareTo(a.percent));
      final top = scores.first;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MoreJobColors.brandSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: MoreJobColors.brandBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusPill(
                  label:
                      'NHÓM NỔI TRỘI · ${widget.type.toUpperCase()}',
                ),
                const SizedBox(height: 8),
                Text(
                  '${top.label} (${top.percent}%)',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(top.tip),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final item in scores)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${item.percent}% (TB ${item.mean.toStringAsFixed(1)}/5)',
                          style: const TextStyle(
                            color: MoreJobColors.brandStrong,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: item.percent / 100.0,
                      minHeight: 8,
                      color: MoreJobColors.brand,
                      backgroundColor: MoreJobColors.border,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.tip,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => setState(() => showResult = false),
            child: const Text('Quay lại bảng câu hỏi'),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: quiz.questions.length,
            itemBuilder: (context, index) {
              final q = quiz.questions[index];
              final val = answers[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Câu ${index + 1}/${quiz.questions.length}: ${q.text}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(5, (i) {
                          final score = i + 1;
                          final selected = val == score;
                          return ChoiceChip(
                            label: Text('$score'),
                            selected: selected,
                            onSelected: (_) =>
                                setState(() => answers[index] = score),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => setState(() => showResult = true),
              child: const Text('Chấm điểm & Xem phân tích'),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 3. SALARY & INCOME TAX CALCULATOR VIEW
// ============================================================================

class SalaryCalculatorView extends StatefulWidget {
  const SalaryCalculatorView({super.key, required this.taxOnly});
  final bool taxOnly;

  @override
  State<SalaryCalculatorView> createState() => _SalaryCalculatorViewState();
}

class _SalaryCalculatorViewState extends State<SalaryCalculatorView> {
  final incomeCtrl = TextEditingController(text: '20000000');
  final dependentsCtrl = TextEditingController(text: '0');
  final insuranceSalaryCtrl = TextEditingController();
  int region = 0;
  bool isNetToGross = false;

  @override
  void dispose() {
    incomeCtrl.dispose();
    dependentsCtrl.dispose();
    insuranceSalaryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(incomeCtrl.text.replaceAll('.', '')) ?? 0;
    final dependents = int.tryParse(dependentsCtrl.text) ?? 0;
    final insSalary = double.tryParse(
      insuranceSalaryCtrl.text.replaceAll('.', ''),
    );
    final breakdown = (!widget.taxOnly && isNetToGross)
        ? netToGross(amount, dependents, region, insSalary)
        : salaryBreakdown(amount, dependents, region, insSalary);
    final parts = incomeTaxParts(breakdown.taxable);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.taxOnly) ...[
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Gross → Net'),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Net → Gross'),
                      ),
                    ],
                    selected: {isNetToGross},
                    onSelectionChanged: (s) =>
                        setState(() => isNetToGross = s.first),
                  ),
                  const SizedBox(height: 14),
                ],
                TextField(
                  controller: incomeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isNetToGross
                        ? 'Thu nhập Net (VNĐ/tháng)'
                        : 'Thu nhập Gross (VNĐ/tháng)',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: dependentsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Số người phụ thuộc',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: region,
                        decoration: const InputDecoration(labelText: 'Vùng'),
                        items: List.generate(
                          4,
                          (i) => DropdownMenuItem(
                            value: i,
                            child: Text('Vùng ${i + 1}'),
                          ),
                        ),
                        onChanged: (v) => setState(() => region = v ?? 0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: insuranceSalaryCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Lương đóng bảo hiểm (bỏ trống = theo Gross)',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: MoreJobColors.brandSoft,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: MoreJobColors.brandBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Lương Gross:'),
                  Text(
                    formatVnd(breakdown.gross),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Lương Net thực nhận:'),
                  Text(
                    formatVnd(breakdown.net),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: MoreJobColors.brandStrong,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              _row('BHXH (8%)', -breakdown.social),
              _row('BHYT (1.5%)', -breakdown.health),
              _row('BHTN (1%)', -breakdown.unemployment),
              _row('Tổng bảo hiểm bắt buộc', -breakdown.insurance, bold: true),
              _row('Giảm trừ gia cảnh', breakdown.deduction),
              _row('Thu nhập tính thuế', breakdown.taxable),
              _row('Thuế TNCN phải nộp', -breakdown.tax, bold: true),
            ],
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
                  'Chi tiết bậc thuế TNCN (Biểu thuế 2026)',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                for (final p in parts)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Bậc ${p.bracket} (${(p.rate * 100).round()}%)',
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text(
                          formatVnd(p.tax),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const FinanceReferenceCard(),
      ],
    );
  }

  Widget _row(String label, double value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          formatVnd(value),
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

// ============================================================================
// 4. SOCIAL & UNEMPLOYMENT INSURANCE VIEW
// ============================================================================

class InsuranceCalculatorView extends StatefulWidget {
  const InsuranceCalculatorView({super.key, required this.unemployment});
  final bool unemployment;

  @override
  State<InsuranceCalculatorView> createState() =>
      _InsuranceCalculatorViewState();
}

class _InsuranceCalculatorViewState extends State<InsuranceCalculatorView> {
  final avgSalaryCtrl = TextEditingController(text: '12000000');
  final monthsAfterCtrl = TextEditingController(text: '24');
  final monthsBeforeCtrl = TextEditingController(text: '0');
  int region = 0;

  @override
  void dispose() {
    avgSalaryCtrl.dispose();
    monthsAfterCtrl.dispose();
    monthsBeforeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avg = double.tryParse(avgSalaryCtrl.text.replaceAll('.', '')) ?? 0;
    final afterM = int.tryParse(monthsAfterCtrl.text) ?? 0;
    final beforeM = int.tryParse(monthsBeforeCtrl.text) ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: avgSalaryCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Tiền lương bình quân đóng BH (VNĐ/tháng)',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                if (widget.unemployment) ...[
                  TextField(
                    controller: monthsAfterCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Số tháng đóng BHTN chưa hưởng',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: region,
                    decoration: const InputDecoration(labelText: 'Vùng lương'),
                    items: List.generate(
                      4,
                      (i) => DropdownMenuItem(
                        value: i,
                        child: Text(
                          'Vùng ${i + 1} (${formatVnd(regionMinimums[i])})',
                        ),
                      ),
                    ),
                    onChanged: (v) => setState(() => region = v ?? 0),
                  ),
                ] else ...[
                  TextField(
                    controller: monthsBeforeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Số tháng đóng trước năm 2014',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: monthsAfterCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Số tháng đóng từ năm 2014 trở đi',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (widget.unemployment)
          Builder(
            builder: (context) {
              final res = unemploymentBenefit(avg, afterM, region);
              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: MoreJobColors.brandSoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: MoreJobColors.brandBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kết quả ước tính trợ cấp thất nghiệp',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text('Mức hưởng mỗi tháng: ${formatVnd(res.monthly)}'),
                    Text('Số tháng được hưởng: ${res.duration} tháng'),
                    const SizedBox(height: 6),
                    Text(
                      'Tổng trợ cấp dự kiến: ${formatVnd(res.total)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: MoreJobColors.brandStrong,
                      ),
                    ),
                  ],
                ),
              );
            },
          )
        else
          Builder(
            builder: (context) {
              final total = socialInsuranceBenefit(avg, beforeM, afterM);
              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: MoreJobColors.brandSoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: MoreJobColors.brandBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ước tính BHXH một lần',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatVnd(total),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: MoreJobColors.brandStrong,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 12),
        const FinanceReferenceCard(),
      ],
    );
  }
}

class FinanceReferenceCard extends StatelessWidget {
  const FinanceReferenceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Căn cứ & phạm vi tính',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ước tính cho người lao động Việt Nam, quy định đối chiếu ngày 10/10/2026. Thuế áp dụng kỳ 2026; mức tham chiếu 2.530.000đ từ 01/07/2026.',
              style: TextStyle(fontSize: 12.5, color: MoreJobColors.muted),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: financeSources
                  .map(
                    (s) => ActionChip(
                      label: Text('${s.label} ↗'),
                      onPressed: () => launchUrl(
                        Uri.parse(s.url),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 5. SCAM CHECK TOOL VIEW
// ============================================================================

class ScamCheckToolView extends StatefulWidget {
  const ScamCheckToolView({super.key});
  @override
  State<ScamCheckToolView> createState() => _ScamCheckToolViewState();
}

class _ScamCheckToolViewState extends State<ScamCheckToolView> {
  final textCtrl = TextEditingController();
  final Set<int> checkedItems = {};

  @override
  void dispose() {
    textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final findings = checkRecruitmentScam(textCtrl.text);
    final totalWarnings = findings.length + checkedItems.length;

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
                  'Dán tin nhắn hoặc nội dung tuyển dụng cần kiểm tra',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: textCtrl,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText:
                        'Ví dụ: Tuyển gấp nhân viên nhập liệu tại nhà, việc nhẹ lương cao, nộp phí hồ sơ 200k...',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Checklist tình huống thực tế',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < scamChecklist.length; i++)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: checkedItems.contains(i),
                    title: Text(
                      scamChecklist[i].label,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      scamChecklist[i].tip,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        checkedItems.add(i);
                      } else {
                        checkedItems.remove(i);
                      }
                    }),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: totalWarnings > 0
                ? MoreJobColors.dangerSoft
                : MoreJobColors.greenSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: totalWarnings > 0
                  ? MoreJobColors.danger
                  : MoreJobColors.greenDark,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                totalWarnings > 0
                    ? 'Phát hiện $totalWarnings dấu hiệu cần cảnh giác cao!'
                    : 'Chưa phát hiện từ khóa rủi ro phổ biến.',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: totalWarnings > 0
                      ? MoreJobColors.danger
                      : MoreJobColors.greenDark,
                ),
              ),
              if (findings.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final f in findings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ${f.label}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '  → ${f.tip}',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 6. BANK CV TOOL VIEW
// ============================================================================

class BankCvToolView extends StatefulWidget {
  const BankCvToolView({super.key});
  @override
  State<BankCvToolView> createState() => _BankCvToolViewState();
}

class _BankCvToolViewState extends State<BankCvToolView> {
  final rawInputCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final contactCtrl = TextEditingController();
  final bankCtrl = TextEditingController(text: 'Vietcombank / BIDV / Techcombank');
  final positionCtrl = TextEditingController(text: 'Chuyên viên Quan hệ Khách hàng');
  final objectiveCtrl = TextEditingController();
  final educationCtrl = TextEditingController();
  final experienceCtrl = TextEditingController();
  final skillsCtrl = TextEditingController();
  final certificatesCtrl = TextEditingController();

  @override
  void dispose() {
    rawInputCtrl.dispose();
    nameCtrl.dispose();
    contactCtrl.dispose();
    bankCtrl.dispose();
    positionCtrl.dispose();
    objectiveCtrl.dispose();
    educationCtrl.dispose();
    experienceCtrl.dispose();
    skillsCtrl.dispose();
    certificatesCtrl.dispose();
    super.dispose();
  }

  void parseFromRaw() {
    final parsed = parseBankCvText(rawInputCtrl.text);
    setState(() {
      if (parsed['objective'] != null) objectiveCtrl.text = parsed['objective']!;
      if (parsed['education'] != null) educationCtrl.text = parsed['education']!;
      if (parsed['experience'] != null) {
        experienceCtrl.text = parsed['experience']!;
      }
      if (parsed['skills'] != null) skillsCtrl.text = parsed['skills']!;
      if (parsed['certificates'] != null) {
        certificatesCtrl.text = parsed['certificates']!;
      }
    });
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tự động tách mục từ nội dung CV có sẵn',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: rawInputCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText:
                        'Dán toàn bộ nội dung CV của bạn (có tiêu đề Học vấn, Kinh nghiệm, Kỹ năng...) để tách tự động',
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: parseFromRaw,
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Chuẩn hóa vào biểu mẫu ngân hàng'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Biểu mẫu CV liên ngân hàng',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 12),
                _field('Họ và tên', nameCtrl),
                _field('Email / Điện thoại', contactCtrl),
                _field('Ngân hàng ứng tuyển', bankCtrl),
                _field('Vị trí ứng tuyển', positionCtrl),
                _field('Mục tiêu nghề nghiệp', objectiveCtrl, lines: 3),
                _field('Học vấn', educationCtrl, lines: 3),
                _field('Kinh nghiệm / Dự án', experienceCtrl, lines: 4),
                _field('Kỹ năng', skillsCtrl, lines: 2),
                _field('Chứng chỉ (TOEIC/IELTS/Tin học)', certificatesCtrl, lines: 2),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: const Border(
              top: BorderSide(color: Color(0xFF1858A5), width: 6),
              left: BorderSide(color: MoreJobColors.border),
              right: BorderSide(color: MoreJobColors.border),
              bottom: BorderSide(color: MoreJobColors.border),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nameCtrl.text.isEmpty ? 'HỌ VÀ TÊN ỨNG VIÊN' : nameCtrl.text,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1858A5),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${positionCtrl.text} · ${bankCtrl.text}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (contactCtrl.text.isNotEmpty) Text(contactCtrl.text),
              const Divider(height: 24),
              if (objectiveCtrl.text.isNotEmpty)
                _previewSection('Mục tiêu nghề nghiệp', objectiveCtrl.text),
              if (educationCtrl.text.isNotEmpty)
                _previewSection('Học vấn', educationCtrl.text),
              if (experienceCtrl.text.isNotEmpty)
                _previewSection('Kinh nghiệm / Dự án', experienceCtrl.text),
              if (skillsCtrl.text.isNotEmpty)
                _previewSection('Kỹ năng', skillsCtrl.text),
              if (certificatesCtrl.text.isNotEmpty)
                _previewSection('Chứng chỉ', certificatesCtrl.text),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  final summary =
                      '${nameCtrl.text}\n${positionCtrl.text} - ${bankCtrl.text}\n${contactCtrl.text}\n\n'
                      'MỤC TIÊU:\n${objectiveCtrl.text}\n\nHỌC VẤN:\n${educationCtrl.text}\n\n'
                      'KINH NGHIỆM:\n${experienceCtrl.text}\n\nKỸ NĂNG:\n${skillsCtrl.text}\n\n'
                      'CHỨNG CHỈ:\n${certificatesCtrl.text}';
                  Clipboard.setData(ClipboardData(text: summary));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã sao chép nội dung CV ngân hàng.'),
                    ),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Sao chép nội dung chuẩn hóa'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: ctrl,
      maxLines: lines,
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => setState(() {}),
    ),
  );

  Widget _previewSection(String title, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: Color(0xFF1858A5),
          ),
        ),
        const SizedBox(height: 4),
        Text(body),
      ],
    ),
  );
}
