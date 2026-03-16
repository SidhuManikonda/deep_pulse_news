class UserCommentEntry {
  final UserCommentDetail comment;
  final UserCommentUser user;
  final UserCommentNews news;

  UserCommentEntry({
    required this.comment,
    required this.user,
    required this.news,
  });

  factory UserCommentEntry.fromJson(Map<String, dynamic> json) {
    return UserCommentEntry(
      comment: UserCommentDetail.fromJson(json['comment'] as Map<String, dynamic>),
      user: UserCommentUser.fromJson(json['user'] as Map<String, dynamic>),
      news: UserCommentNews.fromJson(json['news'] as Map<String, dynamic>),
    );
  }
}

class UserCommentDetail {
  final int id;
  final String content;
  final bool isApproved;
  final DateTime createdAt;

  UserCommentDetail({
    required this.id,
    required this.content,
    required this.isApproved,
    required this.createdAt,
  });

  factory UserCommentDetail.fromJson(Map<String, dynamic> json) {
    return UserCommentDetail(
      id: json['id'] ?? 0,
      content: json['content'] ?? '',
      isApproved: (json['is_approved'] ?? 0) == 1,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

class UserCommentUser {
  final int id;
  final String name;
  final String email;
  final String mobile;
  final String? district;

  UserCommentUser({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
    this.district,
  });

  factory UserCommentUser.fromJson(Map<String, dynamic> json) {
    return UserCommentUser(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      mobile: json['mobile'] ?? '',
      district: json['district'] as String?,
    );
  }
}

class UserCommentNews {
  final int id;
  final String title;
  final String slug;
  final String shortDescription;
  final String status;
  final DateTime? publishedAt;

  UserCommentNews({
    required this.id,
    required this.title,
    required this.slug,
    required this.shortDescription,
    required this.status,
    this.publishedAt,
  });

  factory UserCommentNews.fromJson(Map<String, dynamic> json) {
    return UserCommentNews(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      shortDescription: json['short_description'] ?? '',
      status: json['status'] ?? '',
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'])
          : null,
    );
  }
}
