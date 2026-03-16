import 'dart:io';

class CreateNewsRequest {
  final List<int> topicIds;
  final String status;
  final String title;
  final String slug;
  final String shortDescription;
  final String content;
  final List<int> stateIds;
  final List<int> districtIds;
  final List<int> mandalIds;
  final List<File>? files;

  CreateNewsRequest({
    required this.topicIds,
    required this.status,
    required this.title,
    required this.slug,
    required this.shortDescription,
    required this.content,
    required this.stateIds,
    required this.districtIds,
    required this.mandalIds,
    this.files,
  });

  Map<String, dynamic> toFormData() {
    final Map<String, dynamic> data = {
      'status': status,
      'title': title,
      'slug': slug,
      'short_description': shortDescription,
      'content': content,
    };
    for (int i = 0; i < topicIds.length; i++) {
      data['topic_id[$i]'] = topicIds[i].toString();
    }
    for (int i = 0; i < stateIds.length; i++) {
      data['state_id[$i]'] = stateIds[i].toString();
    }
    for (int i = 0; i < districtIds.length; i++) {
      data['district_id[$i]'] = districtIds[i].toString();
    }
    for (int i = 0; i < mandalIds.length; i++) {
      data['mandal_id[$i]'] = mandalIds[i].toString();
    }
    return data;
  }
}
