import 'package:deep_pulse_news/data/models/feed_ad.dart';
import 'package:deep_pulse_news/data/models/news_location.dart';
import 'package:deep_pulse_news/features/admin/ads_management_controller.dart';
import 'package:flutter_test/flutter_test.dart';

FeedAd ad({
  required int id,
  List<int> topics = const [],
  List<NewsLocation> locations = const [],
  DateTime? updated,
}) => FeedAd(
  id: id,
  url: 'https://x/$id.jpg',
  topicIds: topics,
  locations: locations,
  updatedAt: updated,
);

NewsLocation state(int id) => NewsLocation(id: id, value: '', type: 'state');

void main() {
  test('an ad with topics only matches those topics', () {
    // Mirrors the feed rule: a tab scoped to topic 17 must not show an ad
    // bought for topic 99, while an untargeted ad runs everywhere.
    bool runsOnTopic(FeedAd a, int? topicId) =>
        topicId == null || a.topicIds.isEmpty || a.topicIds.contains(topicId);

    final yourArea = ad(id: 1, topics: [17]);
    final other = ad(id: 2, topics: [99]);
    final untargeted = ad(id: 3);

    expect(runsOnTopic(yourArea, 17), isTrue);
    expect(runsOnTopic(other, 17), isFalse);
    expect(runsOnTopic(untargeted, 17), isTrue);
    // "All Info" has no topic of its own, so everything runs.
    expect(runsOnTopic(other, null), isTrue);
  });

  test('no filters shows everything', () {
    final c = AdsManagementController()..debugSeedAds([ad(id: 1), ad(id: 2)]);
    expect(c.visibleAds.length, 2);
    expect(c.hasActiveFilters, isFalse);
  });

  test('topic filter is OR within the kind', () {
    final c = AdsManagementController()
      ..debugSeedAds([
        ad(id: 1, topics: [17]),
        ad(id: 2, topics: [18]),
        ad(id: 3, topics: [19]),
      ]);
    c.toggleFilterTopic(17);
    expect(c.visibleAds.map((a) => a.id), [1]);
    c.toggleFilterTopic(18);
    expect(c.visibleAds.map((a) => a.id), [1, 2]);
  });

  test('untargeted ads survive a location filter', () {
    final c = AdsManagementController()
      ..debugSeedAds([
        ad(id: 1, locations: [state(1)]),
        ad(id: 2, locations: [state(2)]),
        ad(id: 3), // runs everywhere
      ]);
    c.toggleFilterState(1);
    expect(c.visibleAds.map((a) => a.id), [1, 3]);
  });

  test('date range is inclusive of the whole end day', () {
    final c = AdsManagementController()
      ..debugSeedAds([
        ad(id: 1, updated: DateTime(2026, 9, 10, 9)),
        ad(id: 2, updated: DateTime(2026, 9, 12, 23, 30)),
        ad(id: 3, updated: DateTime(2026, 9, 20)),
      ]);
    c.setDateFilter(DateTime(2026, 9, 10), DateTime(2026, 9, 12));
    expect(c.visibleAds.map((a) => a.id), [1, 2]);
  });

  test('kinds combine with AND, and clearing restores everything', () {
    final c = AdsManagementController()
      ..debugSeedAds([
        ad(id: 1, topics: [17], locations: [state(1)]),
        ad(id: 2, topics: [17], locations: [state(2)]),
      ]);
    c.toggleFilterTopic(17);
    c.toggleFilterState(2);
    expect(c.visibleAds.map((a) => a.id), [2]);
    c.clearFilters();
    expect(c.visibleAds.length, 2);
    expect(c.activeFilterCount, 0);
  });
}
