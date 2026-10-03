import '../json_utils.dart';

/// Segmento de cliente usado para personalización dinámica.
enum UserSegment {
  youth,
  standard,
  premium,
  pyme;

  static UserSegment fromName(String? value) => UserSegment.values.firstWhere(
        (segment) => segment.name == value,
        orElse: () => UserSegment.standard,
      );
}

class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.segment,
    required this.createdAt,
    this.phone,
    this.documentId,
    this.avatarUrl,
    this.onboardingCompleted = false,
  });

  final String id;
  final String name;
  final String email;
  final UserSegment segment;
  final DateTime createdAt;
  final String? phone;
  final String? documentId;
  final String? avatarUrl;
  final bool onboardingCompleted;

  String get firstName => name.trim().split(' ').first;

  User copyWith({
    String? name,
    String? phone,
    String? avatarUrl,
    UserSegment? segment,
    bool? onboardingCompleted,
  }) =>
      User(
        id: id,
        name: name ?? this.name,
        email: email,
        segment: segment ?? this.segment,
        createdAt: createdAt,
        phone: phone ?? this.phone,
        documentId: documentId,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      );

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: jsonString(json, 'id'),
        name: jsonString(json, 'name'),
        email: jsonString(json, 'email'),
        segment: UserSegment.fromName(jsonStringOrNull(json, 'segment')),
        createdAt: jsonDate(json, 'createdAt'),
        phone: jsonStringOrNull(json, 'phone'),
        documentId: jsonStringOrNull(json, 'documentId'),
        avatarUrl: jsonStringOrNull(json, 'avatarUrl'),
        onboardingCompleted: jsonBool(json, 'onboardingCompleted'),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'segment': segment.name,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'phone': phone,
        'documentId': documentId,
        'avatarUrl': avatarUrl,
        'onboardingCompleted': onboardingCompleted,
      };
}
