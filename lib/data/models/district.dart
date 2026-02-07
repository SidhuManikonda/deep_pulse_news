class District {
  final int id;
  final int stateId;
  final String name;
  final String slug;
  final bool isActive;
  final DateTime createdAt;

  District({
    required this.id,
    required this.stateId,
    required this.name,
    required this.slug,
    required this.isActive,
    required this.createdAt,
  });

  factory District.fromJson(Map<String, dynamic> json) {
    return District(
      id: json['id'] ?? 0,
      stateId: json['state_id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      isActive: json['is_active'] == 1,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'state_id': stateId,
      'name': name,
      'slug': slug,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
