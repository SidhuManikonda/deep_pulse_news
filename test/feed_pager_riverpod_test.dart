// Guards the Riverpod conversion of the feed pager: that swiping rebuilds only
// the cards whose active-ness changed, and that nothing writes a provider while
// the tree is building.
import 'package:deep_pulse_news/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the real pager's wiring: same provider, same `select`.
class _Pager extends ConsumerStatefulWidget {
  final int itemCount;
  final String tabKey;
  final void Function(int index) onBuild;
  const _Pager({
    required this.itemCount,
    required this.tabKey,
    required this.onBuild,
  });

  @override
  ConsumerState<_Pager> createState() => _PagerState();
}

class _PagerState extends ConsumerState<_Pager> {
  final _controller = PageController();

  set _currentPage(int v) =>
      ref.read(feedPageProvider(widget.tabKey).notifier).state = v;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _currentPage = 0;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      scrollDirection: Axis.vertical,
      // Keeps the neighbouring pages alive, which is the state the real feed is
      // in mid-swipe — and the only state in which "did the *other* cards
      // rebuild?" is a question worth asking.
      allowImplicitScrolling: true,
      itemCount: widget.itemCount,
      onPageChanged: (i) => _currentPage = i,
      itemBuilder: (context, index) => Consumer(
        builder: (context, ref, _) {
          final isActive = ref.watch(
            feedPageProvider(widget.tabKey).select((p) => p == index),
          );
          widget.onBuild(index);
          return Container(
            alignment: Alignment.center,
            color: isActive ? Colors.amber : Colors.grey,
            child: Text('card $index active=$isActive'),
          );
        },
      ),
    );
  }
}

void main() {
  testWidgets('a page change rebuilds only the cards whose active-ness flipped',
      (tester) async {
    // Drive the provider directly rather than flinging: a fling also makes the
    // PageView build pages newly entering its cache, which has nothing to do
    // with the `select` and would muddy the count.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final builds = <int, int>{};

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: _Pager(
            itemCount: 10,
            tabKey: 'Your Area',
            onBuild: (i) => builds[i] = (builds[i] ?? 0) + 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final live = builds.keys.toSet();
    expect(live.length, greaterThan(1), reason: 'need >1 card alive to test');

    builds.clear();
    container.read(feedPageProvider('Your Area').notifier).state = 1;
    await tester.pump();

    // 0 → 1: exactly those two booleans flip. Every other live card must sit
    // still — that is the whole point of selecting the comparison rather than
    // watching the index.
    expect(builds[0], 1, reason: 'card 0 went inactive, should rebuild once');
    expect(builds[1], 1, reason: 'card 1 went active, should rebuild once');
    for (final index in live) {
      if (index == 0 || index == 1) continue;
      expect(
        builds[index],
        isNull,
        reason: 'card $index rebuilt though its active state never changed — '
            'the select() is not doing its job',
      );
    }
  });

  testWidgets('mount and swipe write no provider during the build phase',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: _Pager(itemCount: 5, tabKey: 'All Info', onBuild: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.fling(find.byType(PageView), const Offset(0, -600), 1200);
    await tester.pumpAndSettle();

    // Riverpod reports a build-phase write as a thrown error, which the test
    // binding records rather than printing.
    expect(tester.takeException(), isNull);
  });

  testWidgets('each tab keeps its own page', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(feedPageProvider('Your Area').notifier).state = 4;
    container.read(feedPageProvider('All Info').notifier).state = 9;

    expect(container.read(feedPageProvider('Your Area')), 4);
    expect(container.read(feedPageProvider('All Info')), 9);
    expect(container.read(feedPageProvider('More')), 0);
  });
}
