import 'dart:convert';

enum NotificationType {
  system,
  auth,
  trip,
  message,
  alert,
  account,
  other
}

enum NotificationPriority {
  low,
  medium,
  high,
  urgent
}

enum NotificationStatus {
  unread,
  read
}

class NotificationItem {
  final String id;
  final String userId;
  final NotificationType type;
  final NotificationPriority priority;
  final NotificationStatus status;
  final String title;
  final String message;
  final String? actionUrl;
  final String? actionLabel;
  final Map<String, dynamic> metadata;
  final List<String> channels;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.priority,
    required this.status,
    required this.title,
    required this.message,
    this.actionUrl,
    this.actionLabel,
    required this.metadata,
    required this.channels,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    // Parse notification type safely
    NotificationType pType = NotificationType.other;
    final typeStr = json['type']?.toString().toLowerCase();
    for (var val in NotificationType.values) {
      if (val.name == typeStr) {
        pType = val;
        break;
      }
    }

    // Parse priority safely
    NotificationPriority pPriority = NotificationPriority.medium;
    final priorityStr = json['priority']?.toString().toLowerCase();
    for (var val in NotificationPriority.values) {
      if (val.name == priorityStr) {
        pPriority = val;
        break;
      }
    }

    // Parse status safely
    NotificationStatus pStatus = NotificationStatus.unread;
    if (json['status']?.toString().toLowerCase() == 'read') {
      pStatus = NotificationStatus.read;
    }

    // Parse channels safely
    List<String> pChannels = [];
    if (json['channels'] is List) {
      pChannels = List<String>.from(json['channels']);
    }

    // Parse metadata safely
    Map<String, dynamic> pMetadata = {};
    if (json['metadata'] is Map) {
      pMetadata = Map<String, dynamic>.from(json['metadata']);
    } else if (json['metadata'] is String) {
      try {
        pMetadata = Map<String, dynamic>.from(jsonDecode(json['metadata']));
      } catch (_) {}
    }

    return NotificationItem(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      type: pType,
      priority: pPriority,
      status: pStatus,
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      actionUrl: json['actionUrl']?.toString(),
      actionLabel: json['actionLabel']?.toString(),
      metadata: pMetadata,
      channels: pChannels,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  NotificationItem copyWith({
    NotificationStatus? status,
  }) {
    return NotificationItem(
      id: id,
      userId: userId,
      type: type,
      priority: priority,
      status: status ?? this.status,
      title: title,
      message: message,
      actionUrl: actionUrl,
      actionLabel: actionLabel,
      metadata: metadata,
      channels: channels,
      createdAt: createdAt,
    );
  }
}
