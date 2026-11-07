// Reproduces the PDF export the way the screen actually runs it: one persistent
// tree, storyStart advanced by setState, onStoryEnd read back between frames.
// The earlier pagination test pumped a fresh tree per page, which hid whatever
// the real loop does differently.
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
      'id': 3389,
      'title': 'మత్స్యకారులకు కీలక హెచ్చరిక.. సముద్రంలోకి వెళ్లే ముందు అప్రమత్తం',
      'short_description':
          'తీర ప్రాంత మత్స్యకారులు అప్రమత్తంగా ఉండాలని అధికారులు సూచించారు. '
              'సముద్రంలోకి వెళ్లే ముందు వాతావరణ పరిస్థితులు పరిశీలించాలి.',
      'content': List.filled(paragraphs, _para).join('\n\n'),
      'status': 'published',
      'created_at': '2026-09-12T10:00:00Z',
      'author': {'name': 'Ravi M.', 'role_name': 'Reader'},
    });

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

/// The screen's harness: one tree, storyStart moved by setState.
class _ExportHarness extends StatefulWidget {
  final News news;
  const _ExportHarness(this.news);
  @override
  State<_ExportHarness> createState() => _ExportHarnessState();
}

class _ExportHarnessState extends State<_ExportHarness> {
  int storyStart = 0;
  bool exporting = true;
  int? lastPageEnd;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            child: NewsPoster(
              news: widget.news,
              storyStart: exporting ? storyStart : 0,
              showContinuedTail: !exporting,
              onStoryEnd: exporting ? (end, _) => lastPageEnd = end : null,
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('the setState-driven export loop walks the whole story',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final news = _news(paragraphs: 6);
    final total = storyLength(news);

    final key = GlobalKey<_ExportHarnessState>();
    await tester.pumpWidget(_ExportHarness(news), wrapWithView: true);
    await tester.pumpAndSettle();

    // Grab the state the way the screen holds its own.
    final state = tester.state<_ExportHarnessState>(
      find.byType(_ExportHarness),
    );
    expect(key, isNotNull);

    final ends = <int>[];
    for (var page = 0; page < 20; page++) {
      state.lastPageEnd = null;
      // ignore: invalid_use_of_protected_member
      state.setState(() {});
      await tester.pump();
      await tester.pump();

      final end = state.lastPageEnd;
      // ignore: avoid_print
      print('page $page: start=${state.storyStart} reported=$end total=$total');
      expect(end, isNotNull,
          reason: 'page $page reported nothing — the export would stop here '
              'and the PDF would be one page');
      ends.add(end!);
      if (end >= total || end <= state.storyStart) break;
      state.storyStart = end;
    }

    expect(ends.length, greaterThan(1),
        reason: 'a story this long must span more than one page');
    expect(ends.last, total, reason: 'the export must reach the last character');
  });
}
