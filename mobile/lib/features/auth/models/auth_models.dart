import 'package:json_annotation/json_annotation.dart';

part 'auth_models.g.dart';

/// Модель ответа на запрос аутентификации
@JsonSerializable()
class AuthResponse {
  final String access;
  final String refresh;
  final UserInfo? user;

  const AuthResponse({
    required this.access,
    required this.refresh,
    this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);

  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);
}

/// Информация о пользователе
@JsonSerializable(fieldRename: FieldRename.snake)
class UserInfo {
  final int id;
  final String? username;
  final String? email;
  final String? phone;
  @JsonKey(name: 'first_name')
  final String? firstName;
  @JsonKey(name: 'last_name')
  final String? lastName;
  @JsonKey(name: 'full_name')
  final String? fullNameFromApi;
  final String role;
  @JsonKey(name: 'role_display')
  final String? roleDisplay;
  final String? avatar;
  final String? locale;
  final String? position;

  const UserInfo({
    required this.id,
    this.username,
    this.email,
    this.phone,
    this.firstName,
    this.lastName,
    this.fullNameFromApi,
    required this.role,
    this.roleDisplay,
    this.avatar,
    this.locale,
    this.position,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) =>
      _$UserInfoFromJson(json);

  Map<String, dynamic> toJson() => _$UserInfoToJson(this);

  String get fullName {
    // Используем full_name из API, если есть
    if (fullNameFromApi != null && fullNameFromApi!.isNotEmpty) {
      return fullNameFromApi!;
    }
    // Иначе формируем из firstName и lastName
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return firstName ?? lastName ?? username ?? email ?? phone ?? 'Пользователь';
  }
}

/// Запрос на логин по телефону/паролю
@JsonSerializable()
class LoginRequest {
  final String? phone;
  final String? email;
  final String? username;
  final String password;
  final String? captchaToken;

  const LoginRequest({
    this.phone,
    this.email,
    this.username,
    required this.password,
    this.captchaToken,
  });

  factory LoginRequest.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestFromJson(json);

  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);
}

/// Запрос на отправку OTP
@JsonSerializable()
class OTPRequest {
  final String phone;
  final String? captchaToken;

  const OTPRequest({
    required this.phone,
    this.captchaToken,
  });

  factory OTPRequest.fromJson(Map<String, dynamic> json) =>
      _$OTPRequestFromJson(json);

  Map<String, dynamic> toJson() => _$OTPRequestToJson(this);
}

/// Запрос на верификацию OTP
@JsonSerializable()
class OTPVerifyRequest {
  final String phone;
  final String code;

  const OTPVerifyRequest({
    required this.phone,
    required this.code,
  });

  factory OTPVerifyRequest.fromJson(Map<String, dynamic> json) =>
      _$OTPVerifyRequestFromJson(json);

  Map<String, dynamic> toJson() => _$OTPVerifyRequestToJson(this);
}

/// Запрос на обновление токена
@JsonSerializable()
class RefreshTokenRequest {
  final String refresh;

  const RefreshTokenRequest({
    required this.refresh,
  });

  factory RefreshTokenRequest.fromJson(Map<String, dynamic> json) =>
      _$RefreshTokenRequestFromJson(json);

  Map<String, dynamic> toJson() => _$RefreshTokenRequestToJson(this);
}

/// Ответ на обновление токена
@JsonSerializable()
class RefreshTokenResponse {
  final String access;

  const RefreshTokenResponse({
    required this.access,
  });

  factory RefreshTokenResponse.fromJson(Map<String, dynamic> json) =>
      _$RefreshTokenResponseFromJson(json);

  Map<String, dynamic> toJson() => _$RefreshTokenResponseToJson(this);
}

