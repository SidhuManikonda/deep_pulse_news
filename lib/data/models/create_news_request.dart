import 'dart:io';

class CreateNewsRequest {
  final List<int> topicIds;
  final String status;
  final String title;
  final String? slug;
  final String shortDescription;
  final String content;
  final List<int> stateIds;
  final List<int> districtIds;
  final List<int> mandalIds;
  final List<File>? files;

  /// Optional sponsor creatives shown inside the article. Image or video.
  /// Uploaded under their own field names (`ad_1`, `ad_2`) rather than with
  /// the story media, so the backend can tell an advert from editorial content.
  final File? ad1;
  final File? ad2;
  final bool isImportant;
  final bool isComment;
  final bool showProfile;

  /// Whether the backend should fire a push for this article when it goes
  /// live. Sent as `is_send_notification`. Defaults to true — publishing
  /// silently is the deliberate choice, not the accident.
  final bool isSendNotification;

  /// Optional title color as a hex string (e.g. "#FF3366"). Null = use default.
  final String? titleColor;

  /// Optional description color hex. Sent to backend as `content_color`.
  final String? descriptionColor;

  /// Optional full-article color hex. Sent to backend as `full_text_color`.
  final String? fullTextColor;

  CreateNewsRequest({
    required this.topicIds,
    required this.status,
    required this.title,
    this.slug,
    required this.shortDescription,
    required this.content,
    required this.stateIds,
    required this.districtIds,
    required this.mandalIds,
    this.files,
    this.ad1,
    this.ad2,
    this.isImportant = false,
    this.isComment = true,
    this.showProfile = true,
    this.isSendNotification = true,
    this.titleColor,
    this.descriptionColor,
    this.fullTextColor,
  });

  /// Ad creatives keyed by the field name the backend expects. Empty when the
  /// author attached none.
  Map<String, File> get adFiles => {
    if (ad1 != null) 'ad_1': ad1!,
    if (ad2 != null) 'ad_2': ad2!,
  };

  Map<String, dynamic> toFormData() {
    final Map<String, dynamic> data = {
      'status': status,
      'title': title,
      if (slug != null) 'slug': slug,
      'short_description': shortDescription,
      'content': content,
      'is_important': isImportant ? '1' : '0',
      'is_comment': isComment ? '1' : '0',
      'show_profile': showProfile ? '1' : '0',
      'is_send_notification': isSendNotification ? '1' : '0',
      // Always sent: a hex like "#FF3366" when a color is chosen, or an empty
      // string to mean "no color / clear it" (so editing can remove a color).
      'title_color': titleColor ?? '',
      'content_color': descriptionColor ?? '',
      'full_text_color': fullTextColor ?? '',
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
