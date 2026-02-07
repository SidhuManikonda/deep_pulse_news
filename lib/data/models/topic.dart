class Topic {
  final int id;
  final String name;
  final String slug;
  final bool isTrending;
  final bool isActive;
  final DateTime createdAt;

  Topic({
    required this.id,
    required this.name,
    required this.slug,
    required this.isTrending,
    required this.isActive,
    required this.createdAt,
  });

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      isTrending: json['is_trending'] == 1,
      isActive: json['is_active'] == 1,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'is_trending': isTrending ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
