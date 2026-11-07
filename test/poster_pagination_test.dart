// The PDF export prints the whole article by rendering one page, asking where
// its text ran out, and starting the next page there. This drives that loop the
// way the exporter does and checks it actually reaches the end.
import 'package:deep_pulse_news/data/models/news.dart';
import 'package:deep_pulse_news/features/news/news_poster_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _para =
    'బంగాళాఖాతంలో వాతావరణ పరిస్థితుల మార్పుల నేపథ్యంలో ఆంధ్రప్రదేశ్ తీర ప్రాంత '
    'మత్స్యకారులు అప్రమత్తంగా ఉండాలని అధికారులు సూచిస్తున్నారు. సముద్రంలోకి వెళ్లే '
    'ముందు వాతావరణ పరిస్థితులు, అధికారుల హెచ్చరికలను తప్పనిసరిగా పరిశీలించాలని '
    'సూచించారు. ';

News _news({required int paragraphs}) => News.fromJson({
      'id': 3085,
      'title': 'మత్స్యకారులకు కీలక హెచ్చరిక.. సముద్రంలోకి వెళ్లే ముందు అప్రమత్తం',
      'short_description': 'తీర ప్రాంత మత్స్యకారులు అప్రమత్తంగా ఉండాలని అధికారులు సూచించారు.',
      'content': List.filled(paragraphs, _para).join('\n\n'),
      'status': 'published',
      'created_at': '2026-09-12T10:00:00Z',
      'author': {'name': 'Deep Pulse', 'role_name': 'News Desk'},
    });

/// The length of the story the poster prints — credit run, summary and body,
/// joined the way `NewsPoster._bodyRuns` joins them. The exporter computes the
/// same number to know when it is finished, so agreeing with it here is part of
/// what this test checks.
int storyLength(News news) {
  final t = news.translations.first;
  final summary = t.shortDescription.trim();
  final content = t.content.trim();
  final joined = summary.isNotEmpty
      ? (content.isNotEmpty && content != summary
          ? '$summary\n\n$content'
          : summary)
      : content;
  return NewsPoster.newsCredit.length + 3 + joined.length;
}

/// Walks the pages exactly as `_captureAllPages` does — same stop condition,
/// so a page the exporter would not capture is not counted here either.
Future<List<int>> paginate(WidgetTester tester, News news,
    {int maxPages = 20}) async {
  final total = storyLength(news);
  final ends = <int>[];
  var start = 0;

  for (var page = 0; page < maxPages; page++) {
    int? reported;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: NewsPoster(
              news: news,
              storyStart: start,
              showContinuedTail: false,
              onStoryEnd: (end, _) => reported = end,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(reported, isNotNull, reason: 'page $page never reported its end');
    ends.add(reported!);
    if (reported! >= total || reported! <= start) break;
    start = reported!;
  }
  return ends;
}

void main() {
  testWidgets('a long story paginates forward and reaches the end',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final news = _news(paragraphs: 14);
    final ends = await paginate(tester, news);

    expect(ends.length, greaterThan(1),
        reason: 'a 14-paragraph story must not fit on one page');

    // Every page moves the story forward — the guard against an endless export.
    for (var i = 1; i < ends.length; i++) {
      expect(ends[i], greaterThan(ends[i - 1]),
          reason: 'page $i did not advance past page ${i - 1}');
    }

    // And the last page finishes the article.
    expect(ends.last, storyLength(news),
        reason: 'the PDF must carry the story to its last character');
  });

  testWidgets('a short story is a single page', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final news = _news(paragraphs: 1);
    final ends = await paginate(tester, news);
    expect(ends.length, 1, reason: 'a short story should not spill over');
  });
}
