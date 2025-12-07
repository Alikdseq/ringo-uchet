import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

/// Информация о пользователе (общая модель)
@JsonSerializable()
class UserInfo {
  final int id;
  final String? username;
  final String? email;
  final String? phone;
  @JsonKey(name: 'first_name')
  final String? firstName;
  @JsonKey(name: 'last_name')
  final String? lastName;
  @JsonKey(defaultValue: 'user')
  final String? role;
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
    this.role,
    this.avatar,
    this.locale,
    this.position,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) => _$UserInfoFromJson(json);
  Map<String, dynamic> toJson() => _$UserInfoToJson(this);

  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return firstName ?? lastName ?? username ?? email ?? phone ?? 'Пользователь';
  }
}

