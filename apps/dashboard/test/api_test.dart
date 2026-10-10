import 'package:flutter_test/flutter_test.dart';
import 'package:hr_dashboard/api.dart';

void main() {
  test('Api starts signed out and has no permissions', () {
    final api = Api('http://localhost:0');
    expect(api.signedIn, isFalse);
    expect(api.can('EMERGENCY_MANAGE'), isFalse);
  });

  test('connection failure surfaces a safe ApiFailure', () async {
    final api = Api('http://127.0.0.1:1');
    await expectLater(
      api.login('a@b.test', 'password-123'),
      throwsA(isA<ApiFailure>()),
    );
  });
}
