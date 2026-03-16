class Comment {
  final int id;
  final String comment;
  final String userName;
  final String? districtName;
  final int? parentId;
  final String? createdAt;
  final String? updatedAt;
  final int repliesCount;
  final List<Comment> replies;

  Comment({
    required this.id,
    required this.comment,
    required this.userName,
    this.districtName,
    this.parentId,
    this.createdAt,
    this.updatedAt,
    this.repliesCount = 0,
    this.replies = const [],
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? 0,
      // Handle both 'comment' (GET) and 'content' (POST) fields
      comment: json['comment'] ?? json['content'] ?? '',
      userName: json['user_name'] ?? '',
      districtName: json['district_name'],
      parentId: json['parent_id'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      repliesCount: json['replies_count'] ?? 0,
      replies: json['replies'] != null
          ? (json['replies'] as List<dynamic>)
              .map((reply) => Comment.fromJson(reply))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'comment': comment,
      'user_name': userName,
      'district_name': districtName,
      'parent_id': parentId,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'replies_count': repliesCount,
      'replies': replies.map((reply) => reply.toJson()).toList(),
    };
  }
}
