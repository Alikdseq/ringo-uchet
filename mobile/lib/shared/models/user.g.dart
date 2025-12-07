// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserInfo _$UserInfoFromJson(Map<String, dynamic> json) => UserInfo(
      id: (json['id'] as num).toInt(),
      username: json['username'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      role: json['role'] as String? ?? 'user',
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
      'role': instance.role,
      'avatar': instance.avatar,
      'locale': instance.locale,
      'position': instance.position,
    };
