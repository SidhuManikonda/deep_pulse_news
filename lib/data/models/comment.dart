class Comment {
  final int id;
  final String comment;
  final String userName;
  final String? districtName;
  final String? profilePhoto;
  final int? parentId;
  final String? createdAt;
  final String? updatedAt;
  final int repliesCount;
  final List<Comment> replies;
  int likesCount;
  int dislikesCount;
  bool? isLikedByUser; // true = liked, false = disliked, null = neither

  Comment({
    required this.id,
    required this.comment,
    required this.userName,
    this.districtName,
    this.profilePhoto,
    this.parentId,
    this.createdAt,
    this.updatedAt,
    this.repliesCount = 0,
    this.replies = const [],
    this.likesCount = 0,
    this.dislikesCount = 0,
    this.isLikedByUser,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    // Extract user info from nested 'user' object if available
    final userObj = json['user'] as Map<String, dynamic>?;
    final userDetail = userObj?['user_detail'] as Map<String, dynamic>?;

    // Get user name: prefer top-level 'user_name', fallback to user.name
    final userName = json['user_name'] ?? userObj?['name'] ?? '';

    // Get district name: prefer top-level, fallback to user_detail.district.name
    final district = userDetail?['district'] as Map<String, dynamic>?;
    final districtName = json['district_name'] ?? district?['name'];

    // Get profile photo from user_detail
    final profilePhoto = userDetail?['profile_photo'] as String?;

    return Comment(
      id: json['id'] ?? 0,
      // Handle both 'comment' (old) and 'content' (new) fields
      comment: json['comment'] ?? json['content'] ?? '',
      userName: userName,
      districtName: districtName,
      profilePhoto: profilePhoto,
      parentId: json['parent_id'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      repliesCount: json['replies_count'] ?? 0,
      replies: json['replies'] != null
          ? (json['replies'] as List<dynamic>)
              .map((reply) => Comment.fromJson(reply))
              .toList()
          : [],
      likesCount: json['likes_count'] ?? 0,
      dislikesCount: json['dislikes_count'] ?? 0,
      isLikedByUser: json['is_liked_by_user'],
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
      'likes_count': likesCount,
      'dislikes_count': dislikesCount,
      'is_liked_by_user': isLikedByUser,
    };
  }
}
