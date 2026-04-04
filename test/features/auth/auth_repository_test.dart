import 'package:flutter_test/flutter_test.dart';
import 'package:kcb_pro_android/features/auth/models/login_response.dart';

void main() {
  test('parses login response with tokens and academic binding info', () {
    final response = LoginResponse.fromJson({
      'access_token': 'access-token',
      'refresh_token': 'refresh-token',
      'token_type': 'bearer',
      'user': {
        'id': 1,
        'school_code': 'hue',
        'academic_username': 'demo_student_id',
      },
    });

    expect(response.tokens.accessToken, 'access-token');
    expect(response.user.academicUsername, 'demo_student_id');
  });
}
