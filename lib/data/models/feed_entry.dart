import 'feed_ad.dart';
import 'news.dart';

/// One page of the home feed: either an article or a standalone advertisement.
///
/// The feed is a vertical pager where one page is one item, so the two kinds
/// have to live in a single ordered list. They're kept as a small union rather
/// than by giving [News] an "is really an ad" flag — an ad has no headline,
/// body, author, likes or comments, and pretending otherwise would leak empty
/// values into every screen that reads an article.
class FeedEntry {
  final News? news;
  final FeedAd? ad;

  const FeedEntry.article(News this.news) : ad = null;
  const FeedEntry.advert(FeedAd this.ad) : news = null;

  bool get isAd => ad != null;
}
