import '../json_utils.dart';

enum AppNotificationType {
  transaction,
  security,
  promo,
  system;

  static AppNotificationType fromName(String? value) =>
      AppNotificationType.values.firstWhere(
        (type) => type.name == value,
        orElse: () => AppNotificationType.system,
      );
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.read = false,
    this.data = const {},
  });

  final String id;
  final String title;
  final String body;
  final AppNotificationType type;
  final DateTime createdAt;
  final bool read;
  final Map<String, dynamic> data;

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        createdAt: createdAt,
        read: read ?? this.read,
        data: data,
      );

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: jsonString(json, 'id'),
        title: jsonString(json, 'title'),
        body: jsonString(json, 'body'),
        type: AppNotificationType.fromName(jsonStringOrNull(json, 'type')),
        createdAt: jsonDate(json, 'createdAt'),
        read: jsonBool(json, 'read'),
        data: jsonMap(json, 'data'),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type.name,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'read': read,
        'data': data,
      };
}
