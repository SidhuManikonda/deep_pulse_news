// Confirms the masthead banner appears on page one only — a carried-over
// page runs just the thin dateline strip, the way a paper does.
import 'package:deep_pulse_news/data/models/news.dart';
import 'package:deep_pulse_news/features/news/news_poster_screen.dart';
import 'package:deep_pulse_news/shared/widgets/app_wordmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

News _news() => News.fromJson({
      'id': 1,
      'title': 'శీర్షిక',
      'short_description': 'సారాంశం ' * 20,
      'content': 'విషయం ' * 200,
      'status': 'published',
      'created_at': '2026-09-12T10:00:00Z',
      'author': {'name': 'Ravi M.', 'role_name': 'Reader'},
      'media': <Map<String, dynamic>>[],
    });

Future<int> logosOnPage(WidgetTester tester, int storyStart) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: NewsPoster(news: _news(), storyStart: storyStart),
      ),
    ),
  ));
  await tester.pump();
  return find.byType(AppWordmark).evaluate().length;
}

void main() {
  testWidgets('the banner runs on page one only', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final first = await logosOnPage(tester, 0);
    final carried = await logosOnPage(tester, 400);

    // ignore: avoid_print
    print('logos: page1=$first continuation=$carried');
    expect(first, greaterThan(0), reason: 'page one carries the banner');
    expect(carried, 0,
        reason: 'a carried-over page must not repeat the banner');
  });
}
