// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuthResponse _$AuthResponseFromJson(Map<String, dynamic> json) => AuthResponse(
      access: json['access'] as String,
      refresh: json['refresh'] as String,
      user: json['user'] == null
          ? null
          : UserInfo.fromJson(json['user'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$AuthResponseToJson(AuthResponse instance) =>
    <String, dynamic>{
      'access': instance.access,
      'refresh': instance.refresh,
      'user': instance.user,
    };

UserInfo _$UserInfoFromJson(Map<String, dynamic> json) => UserInfo(
      id: (json['id'] as num).toInt(),
      username: json['username'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      fullNameFromApi: json['full_name'] as String?,
      role: json['role'] as String,
      roleDisplay: json['role_display'] as String?,
      avatar: json['avatar'] as String?,
      locale: json['locale'] as String?,
      position: json['position'] as String?,
    );

Map<String, dynamic> _$UserInfoToJson(UserInfo instance) => <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'email': instance.email,
      'phone': instance.phone,
      'first_name': instance.firstName,
      'last_name': instance.lastName,
      'full_name': instance.fullNameFromApi,
      'role': instance.role,
      'role_display': instance.roleDisplay,
      'avatar': instance.avatar,
      'locale': instance.locale,
      'position': instance.position,
    };

LoginRequest _$LoginRequestFromJson(Map<String, dynamic> json) => LoginRequest(
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      username: json['username'] as String?,
      password: json['password'] as String,
      captchaToken: json['captchaToken'] as String?,
    );

Map<String, dynamic> _$LoginRequestToJson(LoginRequest instance) =>
    <String, dynamic>{
      'phone': instance.phone,
      'email': instance.email,
      'username': instance.username,
      'password': instance.password,
      'captchaToken': instance.captchaToken,
    };

OTPRequest _$OTPRequestFromJson(Map<String, dynamic> json) => OTPRequest(
      phone: json['phone'] as String,
      captchaToken: json['captchaToken'] as String?,
    );

Map<String, dynamic> _$OTPRequestToJson(OTPRequest instance) =>
    <String, dynamic>{
      'phone': instance.phone,
      'captchaToken': instance.captchaToken,
    };

OTPVerifyRequest _$OTPVerifyRequestFromJson(Map<String, dynamic> json) =>
    OTPVerifyRequest(
      phone: json['phone'] as String,
      code: json['code'] as String,
    );

Map<String, dynamic> _$OTPVerifyRequestToJson(OTPVerifyRequest instance) =>
    <String, dynamic>{
      'phone': instance.phone,
      'code': instance.code,
    };

RefreshTokenRequest _$RefreshTokenRequestFromJson(Map<String, dynamic> json) =>
    RefreshTokenRequest(
      refresh: json['refresh'] as String,
    );

Map<String, dynamic> _$RefreshTokenRequestToJson(
        RefreshTokenRequest instance) =>
    <String, dynamic>{
      'refresh': instance.refresh,
    };

RefreshTokenResponse _$RefreshTokenResponseFromJson(
        Map<String, dynamic> json) =>
    RefreshTokenResponse(
      access: json['access'] as String,
    );

Map<String, dynamic> _$RefreshTokenResponseToJson(
        RefreshTokenResponse instance) =>
    <String, dynamic>{
      'access': instance.access,
    };
