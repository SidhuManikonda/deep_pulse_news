import 'package:deep_pulse_news/data/models/feed_ad.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads title and the three permission flags', () {
    final ad = FeedAd.tryParse({
      'id': 1,
      'image': 'https://cdn/x.jpg',
      'title': 'Summer Sale',
      'is_shareable': true,
      'is_likeable': false,
      'is_reportable': 1,
    });
    expect(ad!.title, 'Summer Sale');
    expect(ad.isShareable, isTrue);
    expect(ad.isLikeable, isFalse);
    expect(ad.isReportable, isTrue);
  });

  test('accepts every boolean spelling the backend might send', () {
    for (final truthy in [true, 1, '1', 'true', 'TRUE', 'yes']) {
      final ad = FeedAd.tryParse({
        'image': 'https://cdn/x.jpg',
        'is_likeable': truthy,
      });
      expect(ad!.isLikeable, isTrue, reason: '$truthy');
    }
    for (final falsy in [false, 0, '0', 'false']) {
      final ad = FeedAd.tryParse({
        'image': 'https://cdn/x.jpg',
        'is_likeable': falsy,
      });
      expect(ad!.isLikeable, isFalse, reason: '$falsy');
    }
  });

  test('absent flags keep the behaviour readers already had', () {
    // An older payload, or a route that does not send them, must not silently
    // strip like/share/report from every ad.
    final ad = FeedAd.tryParse({'image': 'https://cdn/x.jpg'});
    expect(ad!.isShareable, isTrue);
    expect(ad.isLikeable, isTrue);
    expect(ad.isReportable, isTrue);
    expect(ad.title, '');
    expect(ad.isLiked, isFalse);
    expect(ad.likesCount, 0);
  });

  test('like state and count are read when present', () {
    final ad = FeedAd.tryParse({
      'image': 'https://cdn/x.jpg',
      'is_liked': 1,
      'counts': {'likes': 42},
    });
    expect(ad!.isLiked, isTrue);
    expect(ad.likesCount, 42);
  });

  test('withLike swaps only the like state', () {
    final ad = FeedAd.tryParse({
      'image': 'https://cdn/x.jpg',
      'title': 'Keep me',
      'is_likeable': true,
    })!;
    final liked = ad.withLike(liked: true, count: 7);
    expect(liked.isLiked, isTrue);
    expect(liked.likesCount, 7);
    expect(liked.title, 'Keep me');
    expect(liked.url, ad.url);
    expect(liked.isLikeable, isTrue);
  });

  test('flags survive on a youtube ad too', () {
    final ad = FeedAd.tryParse({
      'id': 3,
      'youtube_url': 'https://youtu.be/dQw4w9WgXcQ',
      'title': 'Watch this',
      'is_likeable': false,
    });
    expect(ad!.isYoutube, isTrue);
    expect(ad.title, 'Watch this');
    expect(ad.isLikeable, isFalse);
    expect(ad.isShareable, isTrue);
  });
}
