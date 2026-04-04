import 'session_tokens.dart';

class LoginUser {
  const LoginUser({
    required this.id,
    required this.schoolCode,
    required this.academicUsername,
  });

  final int id;
  final String schoolCode;
  final String academicUsername;

  factory LoginUser.fromJson(Map<String, dynamic> json) {
    return LoginUser(
      id: json['id'] as int,
      schoolCode: json['school_code'] as String,
      academicUsername: json['academic_username'] as String,
    );
  }
}

class LoginResponse {
  const LoginResponse({
    required this.tokens,
    required this.user,
  });

  final SessionTokens tokens;
  final LoginUser user;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      tokens: SessionTokens.fromJson(json),
      user: LoginUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
