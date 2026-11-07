// The article the user actually exported (news 3389), run through the export
// loop. Its only media is a video, so the poster prints no photo — exactly the
// page that came out as a single-page PDF.
import 'package:deep_pulse_news/data/models/news.dart';
import 'package:deep_pulse_news/features/news/news_poster_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

News realNews() => News.fromJson({
      'id': 3389,
      'title': "బీసీల ధర్మ పోరాట దీక్ష విజయవంతం....",
      'short_description': "కేంద్రం చేపడుతున్న జాతీయ జనగణనలో బీసీ కులగణన అంశం లేకపోవడాన్ని నిరసిస్తూ జాతీయ బీసీ సంక్షేమ సంఘం ఆధ్వర్యంలో రాష్ట్రవ్యాప్తంగా బీసీల ధర్మ పోరాట దీక్షకు పిలుపునివ్వడం జరిగింది. అందులో భాగంగా నిజామాబాద్ జిల్లా బీసీ సంక్షేమ సంఘం ఆధ్వర్యంలో పులాంగ్ చౌరస్తా వద్దగల అంబేద్కర్ విగ్రహం వద్ద బీసీ ప్రజలు బీసీల ధర్మ పోరాట దీక్షను చేపట్టారు. \nబీసీ కులగణనను చేపడతామని కేంద్ర ప్రభుత్వం ఏదైతే క్యాబినెట్లో తీర్మానించి ఈరోజు వెనుకడుగు వేయడం సమంజసం కాదని జిల్లా అధ్యక్షుడు నరాల సుధాకర్ అన్నారు.",
      'content': "వెంటనే కేంద్ర ప్రభుత్వం జాతీయ జనగణనలో బిసి కుల గణన అంశాన్ని చేపట్టాలని డిమాండ్ చేశారు.ఎప్పుడో వంద సంవత్సరాల క్రిందట బ్రిటిష్ ప్రభుత్వ హయాంలో చేపట్టిన బీసీ కులగణన తర్వాత ఇప్పటి వరకు బీసీల కుల గణన చేపట్టకపోవడం శోచనీయమని అన్నారు.ఈ దేశంలో ఉన్న ప్రతి ఒక్క జంతువు లెక్క ప్రభుత్వం దగ్గర ఉంది కానీ బీసీల లెక్క లేకపోవడం విచారకరమని అన్నారు.బీసీలు ఎంతమంది ఉన్నారు అనే అంశం తెలిస్తే ఎక్కడ తమ పీఠాలు కదిలిపోతాయోనని బీసీల కులగణనను ప్రభుత్వాలు చేయడం లేదని జిల్లా అధ్యక్షుడు నరాల సుధాకర్ అన్నాడు.బిసి కుల జరిగిన రోజే బీసీలకు న్యాయం జరుగుతుందని రాష్ట్ర ఉపాధ్యక్షుడు బుస ఆంజనేయులు అన్నారు వెంటనే బీసీ కులగణణ అంశాన్ని చేర్చాలని డిమాండ్ చేశారు.ఈ కార్యక్రమంలో నరాల సుధాకర్తో పాటు బుస్స ఆంజనేయులు కొయ్యాడ శంకర్, శ్రీలత,బగ్గలి అజయ్,చంద్రకాంత్,సాయి బసవ,అపర్ణ,సురేందర్, సదానంద్, గంగాధర్,ఆర్టీసీ శ్రీనివాస్,నరసయ్య,అనిల్, జయ,రుక్మిణి,నరేందర్,దారం భూమన్న, సత్యనారాయణ,అంకంరావు తదితర బీసీ నాయకులు పెద్ద ఎత్తున పాల్గొన్నారు.",
      'status': 'published',
      'created_at': '2026-09-12T10:00:00Z',
      'author': {'name': 'Ravi M.', 'role_name': 'Reader'},
      'media': <Map<String, dynamic>>[],
    });

class _H extends StatefulWidget {
  final News news;
  const _H(this.news);
  @override
  State<_H> createState() => _HState();
}

class _HState extends State<_H> {
  int storyStart = 0;
  int? lastEnd;
  bool lastComplete = false;
  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              child: NewsPoster(
                news: widget.news,
                storyStart: storyStart,
                showContinuedTail: false,
                onStoryEnd: (end, complete) {
                  lastEnd = end;
                  lastComplete = complete;
                },
              ),
            ),
          ),
        ),
      );
}

void main() {
  testWidgets('the real article spans several pages and finishes',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_H(realNews()));
    await tester.pumpAndSettle();
    final s = tester.state<_HState>(find.byType(_H));

    final ends = <int>[];
    var finished = false;
    for (var p = 0; p < 20; p++) {
      s.lastEnd = null;
      s.lastComplete = false;
      // ignore: invalid_use_of_protected_member
      s.setState(() {});
      await tester.pump();
      await tester.pump();

      final end = s.lastEnd;
      expect(end, isNotNull, reason: 'page $p reported nothing');
      ends.add(end!);
      if (s.lastComplete) {
        finished = true;
        break;
      }
      expect(end, greaterThan(s.storyStart),
          reason: 'page $p made no progress');
      s.storyStart = end;
    }

    // ignore: avoid_print
    print('real article: ${ends.length} pages, ends=$ends');
    expect(finished, isTrue, reason: 'the export never reached the end');
    expect(ends.length, greaterThan(1),
        reason: 'a 1394-character story does not fit on one page — this is '
            'the single-page PDF the reader reported');
  });
}
