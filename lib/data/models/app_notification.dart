
class AppNotification {
  final String id;
  final String? type;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.data,
    required this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;
  String? get title => data['title']?.toString();
  String? get body =>
      (data['message'] ?? data['body'] ?? data['description'])?.toString();
  String? get description => data['description']?.toString();
  String? get image => data['image']?.toString();
  String? get payloadType => data['type']?.toString();
  String? get newsId => data['news_id']?.toString();

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final raw = json['data'];
    final payload = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};

    return AppNotification(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString(),
      data: payload,
      readAt: _parseDate(json['read_at']),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
