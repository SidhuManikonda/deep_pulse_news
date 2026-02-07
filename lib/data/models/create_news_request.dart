import 'dart:io';

class CreateNewsRequest {
  final int topicId;
  final String status;
  final String title;
  final String slug;
  final String shortDescription;
  final String content;
  final int stateId;
  final int districtId;
  final int mandalId;
  final List<File>? files;

  CreateNewsRequest({
    required this.topicId,
    required this.status,
    required this.title,
    required this.slug,
    required this.shortDescription,
    required this.content,
    required this.stateId,
    required this.districtId,
    required this.mandalId,
    this.files,
  });

  Map<String, String> toFormData() {
    return {
      'topic_id': topicId.toString(),
      'status': status,
      'title': title,
      'slug': slug,
      'short_description': shortDescription,
      'content': content,
      'state_id': stateId.toString(),
      'district_id': districtId.toString(),
      'mandal_id': mandalId.toString(),
    };
  }
}
