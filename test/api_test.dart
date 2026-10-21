import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:more_job_fem/api.dart';

void main() {
  test('unwraps a paginated API response', () async {
    final api = MoreJobApi(
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/jobs');
        expect(request.url.queryParameters['page'], '1');
        return http.Response(
          '{"success":true,"data":{"content":[],"page":1,"totalPages":2,"last":true}}',
          200,
        );
      }),
    );
    final data = await api.get('/jobs', query: {'page': '1'});
    expect(data['page'], 1);
    expect(data['last'], true);
  });

  test('uses backend error message', () async {
    final api = MoreJobApi(
      client: MockClient(
        (request) async => http.Response(
          '{"success":false,"message":"Tin đã đủ người"}',
          409,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    await expectLater(
      api.get('/jobs/1'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Tin đã đủ người',
        ),
      ),
    );
  });
}
