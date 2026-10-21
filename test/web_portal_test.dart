import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:more_job_fem/web_portal.dart';

void main() {
  test('web feature routes are unique and stay on app origin', () {
    final features = [...publicFeatures, ...studentFeatures, ...adminFeatures];
    final paths = features.map((feature) => feature.path).toList();
    expect(paths.toSet().length, paths.length);
    expect(paths.every((path) => path.startsWith('/')), isTrue);
    expect(Uri.parse(webBaseUrl).scheme, 'https');
  });

  testWidgets('feature hub exposes student and public tools', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WebPortalHub()));
    expect(find.text('Tìm việc và so khớp CV'), findsOneWidget);
    expect(find.text('Công khai và tiện ích'), findsOneWidget);
    await tester.tap(find.text('Công khai và tiện ích'));
    await tester.pumpAndSettle();
    expect(find.text('Trắc nghiệm MBTI'), findsOneWidget);
  });
}
