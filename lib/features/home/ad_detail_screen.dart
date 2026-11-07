import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_font_sizes.dart';
import '../../data/models/feed_ad.dart';
import '../../providers/app_providers.dart';
import 'widgets/full_page_ad_card.dart';

/// One ad on its own, opened from a shared link
/// (https://api.deeppulse.media/ads/{id}). Shows the same full-page card the
/// feed does, so the ad looks and behaves exactly as it did where it was
/// shared from.
class AdDetailScreen extends ConsumerStatefulWidget {
  final int adId;

  const AdDetailScreen({super.key, required this.adId});

  @override
  ConsumerState<AdDetailScreen> createState() => _AdDetailScreenState();
}

class _AdDetailScreenState extends ConsumerState<AdDetailScreen> {
  late Future<FeedAd?> _ad = _load();

  Future<FeedAd?> _load() => ref.read(adsRepositoryProvider).getAd(widget.adId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            FutureBuilder<FeedAd?>(
              future: _ad,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }
                final ad = snapshot.data;
                // Deleted, unpublished, or the network failed — say so rather
                // than leaving a blank black page.
                if (ad == null || ad.isDeleted || ad.status != 'published') {
                  return _unavailable();
                }
                return FullPageAdCard(ad: ad, isActive: true);
              },
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Material(
                color: Colors.black45,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _unavailable() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'This ad is no longer available',
            style: TextStyle(
              fontSize: scaledFontSize(15),
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _ad = _load()),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
