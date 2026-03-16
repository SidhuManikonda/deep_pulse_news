class Topic {
  final int id;
  final String name;
  final String? slug;
  final bool? isTrending;
  final bool? isActive;
  final DateTime? createdAt;

  Topic({
    required this.id,
    required this.name,
    this.slug,
    this.isTrending,
    this.isActive,
    this.createdAt,
  });

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      isTrending: json['is_trending'] == 1,
      isActive: json['is_active'] == 1,
      createdAt:json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

}
