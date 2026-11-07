import 'package:deep_pulse_news/data/models/create_news_request.dart';
import 'package:deep_pulse_news/data/models/feed_ad.dart';
import 'package:deep_pulse_news/data/models/news.dart';
import 'package:deep_pulse_news/data/models/news_ad.dart';
import 'package:deep_pulse_news/enums/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const link = 'https://youtu.be/dQw4w9WgXcQ';

  test('request sends youtube_url_1/2, empty when a slot has none', () {
    final f = CreateNewsRequest(
      topicIds: [1], status: 'published', title: 'T',
      shortDescription: 'S', content: 'C',
      stateIds: [1], districtIds: [], mandalIds: [],
      youtubeUrl1: link,
    ).toFormData();
    expect(f['youtube_url_1'], link);
    expect(f['youtube_url_2'], '');
  });

  test('response youtube_url_N becomes a youtube ad in the right slot', () {
    final news = News.fromJson({
      'id': 1,
      'ads': [],
      'youtube_url_2': link,
      'locations': [],
      'media': [],
    });
    expect(news.ads.length, 1);
    expect(news.ads.single.slot, 2);
    expect(news.ads.single.isYoutube, isTrue);
    expect(news.youtubeUrlForSlot(2), link);
    expect(news.youtubeUrlForSlot(1), isNull);
  });

  test('a file ad already in a slot is not displaced by a link', () {
    final news = News.fromJson({
      'id': 1,
      'ads': [
        {'slot': 1, 'file_url': 'https://cdn/x.jpg'},
      ],
      'youtube_url_1': link,
      'locations': [],
      'media': [],
    });
    expect(news.ads.length, 1);
    expect(news.ads.single.isYoutube, isFalse);
  });

  test('a malformed link produces no ad at all', () {
    final news = News.fromJson({
      'id': 1,
      'ads': [],
      'youtube_url_1': 'https://vimeo.com/12345',
      'locations': [],
      'media': [],
    });
    expect(news.ads, isEmpty);
    expect(NewsAd.youtube(url: 'nonsense', slot: 1), isNull);
  });

  test('full-screen ad reads youtube_url and needs no file', () {
    final ad = FeedAd.tryParse({
      'id': 9,
      'youtube_url': link,
      'status': 'published',
    });
    expect(ad, isNotNull);
    expect(ad!.isYoutube, isTrue);
    expect(ad.mediaType, 'youtube');
    expect(ad.youtubeThumbnail, contains('img.youtube.com'));
  });

  test('a full-screen ad with a bad link falls back to the file keys', () {
    // Not a YouTube URL, so it must not be treated as a link ad; the uploaded
    // file is still the creative.
    final ad = FeedAd.tryParse({
      'id': 9,
      'youtube_url': 'https://vimeo.com/1',
      'image': 'https://cdn/x.jpg',
    });
    expect(ad, isNotNull);
    expect(ad!.isYoutube, isFalse);
    expect(ad.url, 'https://cdn/x.jpg');
  });

  test('reads the link from the translation, where the API puts it', () {
    // The live payload nests these beside the title and body rather than at
    // the article's top level.
    final news = News.fromJson({
      'id': 4999,
      'ads': [],
      'translations': [
        {
          'id': 1,
          'title': 'T',
          'short_description': 'S',
          'content': 'C',
          'youtube_url_1': link,
          'youtube_url_2': null,
        },
      ],
      'locations': [],
      'media': [],
    });
    expect(news.ads.length, 1);
    expect(news.ads.single.slot, 1);
    expect(news.ads.single.isYoutube, isTrue);
    expect(news.youtubeUrlForSlot(1), link);
  });

  test('a top-level link still wins when a route flattens it', () {
    final news = News.fromJson({
      'id': 1,
      'ads': [],
      'youtube_url_2': link,
      'translations': [
        {'id': 1, 'title': 'T', 'youtube_url_2': null},
      ],
      'locations': [],
      'media': [],
    });
    expect(news.youtubeUrlForSlot(2), link);
  });

  test('only News Desk and above may post youtube ads', () {
    expect(UserRole.admin.canPostYoutubeAds, isTrue);
    expect(UserRole.subAdmin.canPostYoutubeAds, isTrue);
    expect(UserRole.distReporter.canPostYoutubeAds, isTrue);
    expect(UserRole.reporter.canPostYoutubeAds, isFalse);
    expect(UserRole.reader.canPostYoutubeAds, isFalse);
  });
}
