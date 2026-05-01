class NewsLocation {
  final int id;
  final String value;
  final String type; // "topic", "state", "district", "mandal"

  NewsLocation({
    required this.id,
    required this.value,
    required this.type,
  });

  factory NewsLocation.fromJson(Map<String, dynamic> json) {
    return NewsLocation(
      id: json['id'] ?? 0,
      value: json['value'] ?? '',
      type: json['type'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'value': value,
      'type': type,
    };
  }

  bool get isTopic => type == 'topic';
  bool get isState => type == 'state';
  bool get isDistrict => type == 'district';
  bool get isMandal => type == 'mandal';
}
