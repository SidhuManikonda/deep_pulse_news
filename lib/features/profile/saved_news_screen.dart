import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../core/services/saved_news_service.dart';
import '../../data/models/news.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/cached_image_widget.dart';
import '../news/news_detail_screen_v2.dart';

class SavedNewsScreen extends ConsumerStatefulWidget {
  const SavedNewsScreen({super.key});

  @override
  ConsumerState<SavedNewsScreen> createState() => _SavedNewsScreenState();
}

class _SavedNewsScreenState extends ConsumerState<SavedNewsScreen> {
  late final SavedNewsService _savedNewsService;
  List<News> _savedNews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _savedNewsService = SavedNewsService(userId: ref.read(authViewModelProvider).user?.id);
    _loadSavedNews();
  }

  Future<void> _loadSavedNews() async {
    final news = await _savedNewsService.getSavedNews();
    if (mounted) {
      setState(() {
        _savedNews = news;
        _isLoading = false;
      });
    }
  }

  Future<void> _removeNews(int newsId) async {
    await _savedNewsService.removeNews(newsId);
    _loadSavedNews();
  }

  String _getNewsTitle(News news) {
    if (news.translations.isNotEmpty) {
      return news.translations.first.title;
    }
    return 'Untitled';
  }

  String _getNewsDescription(News news) {
    if (news.translations.isNotEmpty) {
      return news.translations.first.shortDescription;
    }
    return '';
  }

  String? _getNewsThumbnail(News news) {
    // Prefer image, fallback to video URL for thumbnail
    final imageMedia = news.media.where((m) => m.type == 'image').toList();
    if (imageMedia.isNotEmpty) {
      return imageMedia.first.fileUrl;
    }
    return null;
  }

  bool _hasVideo(News news) {
    return news.media.any((m) => m.type == 'video');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Saved News',
          style: TextStyle(
            fontSize: scaledFontSize(20),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedNews.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark_outline,
                        size: 64,
                        color: theme.appGrey400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No saved news',
                        style: TextStyle(
                          fontSize: scaledFontSize(18),
                          fontWeight: FontWeight.w600,
                          color: theme.appTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'News you save will appear here',
                        style: TextStyle(
                          fontSize: scaledFontSize(14),
                          color: theme.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _savedNews.length,
                  itemBuilder: (context, index) {
                    final news = _savedNews[index];
                    final imageUrl = _getNewsThumbnail(news);
                    final isVideo = _hasVideo(news);

                    return Dismissible(
                      key: Key('saved_${news.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                        ),
                      ),
                      onDismissed: (_) => _removeNews(news.id),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  NewsDetailScreenV2(initialNewsItem: news),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: theme.appCard,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Thumbnail
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  bottomLeft: Radius.circular(12),
                                ),
                                child: SizedBox(
                                  width: 100,
                                  height: 90,
                                  child: imageUrl != null
                                      ? Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            CachedImageWidget(
                                              imageUrl: imageUrl,
                                              fit: BoxFit.cover,
                                            ),
                                            if (isVideo)
                                              Center(
                                                child: Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withOpacity(0.5),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                                                ),
                                              ),
                                          ],
                                        )
                                      : Container(
                                          color: theme.appGrey200,
                                          child: Icon(
                                            isVideo ? Icons.videocam : Icons.image,
                                            color: theme.appGrey400,
                                          ),
                                        ),
                                ),
                              ),
                              // Content
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getNewsTitle(news),
                                        style: TextStyle(
                                          fontSize: scaledFontSize(15),
                                          fontWeight: FontWeight.w600,
                                          color: theme.appTextPrimary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _getNewsDescription(news),
                                        style: TextStyle(
                                          fontSize: scaledFontSize(12),
                                          color: theme.appTextSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Remove button
                              IconButton(
                                icon: const Icon(Icons.bookmark,
                                    color: Colors.amber),
                                onPressed: () => _removeNews(news.id),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
