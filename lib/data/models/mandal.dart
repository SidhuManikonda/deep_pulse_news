class Mandal {
  final int id;
  final int districtId;
  final String name;
  final String slug;
  final bool isActive;
  final DateTime createdAt;

  Mandal({
    required this.id,
    required this.districtId,
    required this.name,
    required this.slug,
    required this.isActive,
    required this.createdAt,
  });

  factory Mandal.fromJson(Map<String, dynamic> json) {
    return Mandal(
      id: json['id'] ?? 0,
      districtId: json['district_id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      isActive: json['is_active'] == 1,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'district_id': districtId,
      'name': name,
      'slug': slug,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
