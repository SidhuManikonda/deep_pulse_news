class State {
  final int id;
  final String name;
  final String slug;
  final bool isActive;
  final DateTime createdAt;

  State({
    required this.id,
    required this.name,
    required this.slug,
    required this.isActive,
    required this.createdAt,
  });

  factory State.fromJson(Map<String, dynamic> json) {
    return State(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      isActive: json['is_active'] == 1,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
