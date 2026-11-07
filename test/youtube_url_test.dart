import 'package:deep_pulse_news/core/utils/youtube_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const id = 'dQw4w9WgXcQ';

  test('accepts every shape an editor might paste', () {
    for (final url in [
      'https://www.youtube.com/watch?v=$id',
      'https://youtube.com/watch?v=$id',
      'http://m.youtube.com/watch?v=$id',
      'https://youtu.be/$id',
      'https://youtu.be/$id?si=abc123XYZ',
      'https://www.youtube.com/shorts/$id',
      'https://www.youtube.com/embed/$id',
      'https://www.youtube.com/live/$id',
      'youtube.com/watch?v=$id',
      '  https://youtu.be/$id  ',
      'https://www.youtube.com/watch?v=$id&t=42s&feature=share',
      id,
    ]) {
      expect(YoutubeUrl.videoId(url), id, reason: url);
    }
  });

  test('rejects anything that is not a youtube video', () {
    for (final url in [
      null,
      '',
      '   ',
      'https://vimeo.com/123456',
      'https://example.com/watch?v=$id',
      'https://www.youtube.com/watch?v=tooshort',
      'https://youtu.be/',
      'not a url at all',
    ]) {
      expect(YoutubeUrl.videoId(url), isNull, reason: '$url');
      expect(YoutubeUrl.isValid(url), isFalse);
    }
  });

  test('builds thumbnail and canonical watch url', () {
    expect(
      YoutubeUrl.thumbnail('https://youtu.be/$id'),
      'https://img.youtube.com/vi/$id/hqdefault.jpg',
    );
    expect(
      YoutubeUrl.watchUrl('https://www.youtube.com/shorts/$id'),
      'https://www.youtube.com/watch?v=$id',
    );
    expect(YoutubeUrl.thumbnail('https://vimeo.com/1'), isNull);
  });
}
