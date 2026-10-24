import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:more_job_fem/admin_pages.dart';
import 'package:more_job_fem/ai_interview.dart';
import 'package:more_job_fem/api.dart';
import 'package:more_job_fem/billing_pages.dart';
import 'package:more_job_fem/cv_studio.dart';
import 'package:more_job_fem/student_pages.dart';
import 'package:more_job_fem/theme.dart';
import 'package:more_job_fem/utilities.dart';

MoreJobApi createMockApi() {
  final client = MockClient((request) async {
    final path = request.url.path;
    if (path.endsWith('/billing/plans')) {
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [
            {
              'code': 'STUDENT_AI_PRO',
              'name': 'Gói Student AI Pro',
              'price': 99000,
              'description': 'Mở khóa toàn bộ tính năng AI',
            }
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    if (path.endsWith('/cv-templates')) {
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [
            {
              'id': 1,
              'code': 'ATS_MODERN',
              'name': 'ATS Modern Clean',
              'category': 'Tech',
              'special': false,
            }
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    if (path.endsWith('/admin/sourced-jobs')) {
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [
            {
              'id': 101,
              'title': 'Backend Java Engineer',
              'companyName': 'MoreJob Tech',
              'reviewStatus': 'PENDING',
            }
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    return http.Response(
      jsonEncode({'success': true, 'data': []}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
  return MoreJobApi(client: client);
}

void main() {
  test('Theme uses Be Vietnam Pro and web brand palette', () {
    final theme = MoreJobTheme.lightTheme;
    expect(MoreJobTheme.fontFamily, 'Be Vietnam Pro');
    expect(MoreJobColors.brand, const Color(0xFFFF7A11));
    expect(MoreJobColors.brandStrong, const Color(0xFFFF5A00));
    expect(MoreJobColors.ink, const Color(0xFF102033));
    expect(MoreJobColors.navy, const Color(0xFF0F3560));
    expect(MoreJobColors.green, const Color(0xFF10B981));
    expect(theme.colorScheme.primary, MoreJobColors.brand);
  });

  test('Career utilities calculations match web logic', () {
    // Gross to Net calculation
    final breakdown = salaryBreakdown(20000000, 0, 0, null);
    expect(breakdown.gross, 20000000);
    expect(breakdown.net, lessThan(20000000));
    expect(breakdown.net, greaterThan(15000000));

    // Bank CV parser
    final parsed = parseBankCvText('Mục tiêu nghề nghiệp:\nChuyên viên tín dụng\nHọc vấn:\nĐH Kinh Tế');
    expect(parsed['objective'], contains('Chuyên viên tín dụng'));
    expect(parsed['education'], contains('ĐH Kinh Tế'));
  });

  testWidgets('UtilitiesHubPage renders all 9 career utilities', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MoreJobTheme.lightTheme,
        home: const UtilitiesHubPage(),
      ),
    );
    expect(utilityTools.length, 9);
    expect(find.text('Hiểu bản thân. Chủ động sự nghiệp.'), findsOneWidget);
    expect(find.text('Trắc nghiệm tính cách MBTI'), findsOneWidget);
  });

  testWidgets('CvStudioPage, AiInterviewPage, BillingPricingPage & AdminPortalPage render',
      (tester) async {
    final mockApi = createMockApi();

    await tester.pumpWidget(
      MaterialApp(
        theme: MoreJobTheme.lightTheme,
        home: Scaffold(body: CvStudioPage(api: mockApi)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('CV Studio & Kho mẫu chuẩn ATS'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: MoreJobTheme.lightTheme,
        home: Scaffold(body: AiInterviewPage(api: mockApi)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Phỏng vấn thử AI (AI Mock Interview)'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: MoreJobTheme.lightTheme,
        home: Scaffold(body: BillingPricingPage(api: mockApi)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nâng cấp Tài khoản & Thanh toán PayOS'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: MoreJobTheme.lightTheme,
        home: AdminPortalPage(api: mockApi, onLogout: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ADMIN PORTAL'), findsOneWidget);
    expect(find.text('Backend Java Engineer'), findsOneWidget);
  });

  testWidgets('StudentDashboardView renders KPIs and actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MoreJobTheme.lightTheme,
        home: Scaffold(
          body: StudentDashboardView(
            profile: const {
              'fullName': 'Nguyễn Văn A',
              'major': 'Kỹ thuật Phần mềm',
              'university': 'ĐH Bách Khoa',
            },
            cvs: const [{'id': 1, 'title': 'CV Java'}],
            applications: const [{'id': 10, 'status': 'APPLIED'}],
            savedJobs: const [],
            recommendedJobs: const [
              {
                'id': 99,
                'title': 'Fresher Flutter Developer',
                'companyName': 'MoreJob Corp',
                'location': 'TP.HCM',
              }
            ],
            interviews: const [],
            onNavigateJobs: () {},
            onNavigateCvStudio: () {},
            onNavigateApplications: () {},
            onNavigateAiInterview: () {},
            onSelectJob: (_) {},
          ),
        ),
      ),
    );
    expect(find.textContaining('Nguyễn Văn A'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Fresher Flutter Developer'), findsOneWidget);
  });
}
