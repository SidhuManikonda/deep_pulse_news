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

  /// A YouTube link standing in for an uploaded creative, per slot, sent as
  /// `youtube_url_1` / `youtube_url_2`.
  ///
  /// A slot holds a file or a link, never both — so setting one of these means
  /// [ad1] / [ad2] is null for that slot, and an empty string clears whatever
  /// the slot held. Always sent for the same reason the colours are: an edit
  /// that removes a link has to say so, and a missing key can't.
  final String? youtubeUrl1;
  final String? youtubeUrl2;

  /// Story media to drop on an edit, by `NewsMedia.id`, sent as
  /// `delete_media_ids[]`. Taking a thumbnail out of the form only hides it
  /// locally — the file stays on the article until its id is listed here.
  final List<int> deleteMediaIds;

  /// Ad places to clear on an edit, sent as `remove_ad_1` / `remove_ad_2` with
  /// a 0/1 value. Each slot carries its own flag rather than sharing a list:
  /// a story's ads have no id of their own (the payload describes them as
  /// `{slot, file_url}`), so the slot is the only way to name one.
  ///
  /// Replacing a creative needs neither flag — posting a file as `ad_1` /
  /// `ad_2` overwrites that place — but emptying one has no other expression.
  final bool removeAd1;
  final bool removeAd2;
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
    this.youtubeUrl1,
    this.youtubeUrl2,
    this.deleteMediaIds = const [],
    this.removeAd1 = false,
    this.removeAd2 = false,
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
      // Always sent so an edit that un-marks a slot says so explicitly rather
      // than leaving the backend to infer it from a missing key.
      'youtube_url_1': youtubeUrl1 ?? '',
      'youtube_url_2': youtubeUrl2 ?? '',
      'remove_ad_1': removeAd1 ? '1' : '0',
      'remove_ad_2': removeAd2 ? '1' : '0',
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
    for (int i = 0; i < deleteMediaIds.length; i++) {
      data['delete_media_ids[$i]'] = deleteMediaIds[i].toString();
    }
    return data;
  }
}
