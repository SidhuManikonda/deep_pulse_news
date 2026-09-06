import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../data/models/app_notification.dart';
import '../../data/repositories/notification_repository.dart';
import '../../shared/widgets/cached_image_widget.dart';
import '../news/news_detail_screen_v2.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final NotificationRepository _notifRepo = NotificationRepositoryImpl();

  List<AppNotification> _items = [];
  bool _isLoading = true;
  bool _isMarkingAll = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final list = await _notifRepo.getNotifications();
      if (!mounted) return;
      setState(() {
        _items = list;
        _error = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _onTapNotification(AppNotification notif) async {
    if (!notif.isRead) {
      setState(() {
        _items = _items
            .map((n) => n.id == notif.id
                ? AppNotification(
                    id: n.id,
                    type: n.type,
                    data: n.data,
                    readAt: DateTime.now(),
                    createdAt: n.createdAt,
                  )
                : n)
            .toList();
      });
      _notifRepo.markAsRead(notif.id);
    }

    // Deeplink: hand the id straight to NewsDetailScreenV2 — it fetches the
    // article itself and shows its own loader / error UI. No separate
    // GET /news/{id} from this screen so the inbox stays focused.
    final newsIdStr = notif.newsId;
    if (newsIdStr == null || newsIdStr.isEmpty) return;
    final newsId = int.tryParse(newsIdStr);
    if (newsId == null) return;

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsDetailScreenV2(initialNewsId: newsId),
      ),
    );
  }

  Future<void> _markAllRead() async {
    if (_isMarkingAll) return;
    final hasUnread = _items.any((n) => !n.isRead);
    if (!hasUnread) return;

    setState(() => _isMarkingAll = true);
    final ok = await _notifRepo.markAllAsRead();
    if (!mounted) return;

    if (ok) {
      final now = DateTime.now();
      setState(() {
        _items = _items
            .map((n) => n.isRead
                ? n
                : AppNotification(
                    id: n.id,
                    type: n.type,
                    data: n.data,
                    readAt: now,
                    createdAt: n.createdAt,
                  ))
            .toList();
        _isMarkingAll = false;
      });
    } else {
      setState(() => _isMarkingAll = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to mark all as read'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unreadCount = _items.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Text(
              'Notifications',
              style: TextStyle(
                fontSize: scaledFontSize(18),
                fontWeight: FontWeight.w700,
                color: theme.appTextPrimary,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: theme.appPrimary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount',
                  style: TextStyle(
                    fontSize: scaledFontSize(11),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: _isMarkingAll ? null : _markAllRead,
              icon: _isMarkingAll
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.done_all_rounded,
                      size: 18,
                      color: theme.appPrimary,
                    ),
              label: Text(
                'Mark all read',
                style: TextStyle(
                  fontSize: scaledFontSize(12),
                  color: theme.appPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Icon(Icons.wifi_off_rounded, size: 48, color: theme.appTextLight),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Failed to load notifications',
              style: TextStyle(
                fontSize: scaledFontSize(15),
                fontWeight: FontWeight.w600,
                color: theme.appTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Icon(
            Icons.notifications_none_rounded,
            size: 56,
            color: theme.appTextLight,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'You\'re all caught up',
              style: TextStyle(
                fontSize: scaledFontSize(15),
                fontWeight: FontWeight.w600,
                color: theme.appTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: scaledFontSize(12),
                color: theme.appTextLight,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) =>
          _NotificationCard(notif: _items[i], onTap: _onTapNotification),
    );
  }
}

/// Warm tint applied to already-read notification cards. Same orange the
/// profile screen uses for Location Management, so it reads as part of the
/// existing palette rather than a new accent.
const Color _kReadTint = Color(0xFFFF9F43);

class _NotificationCard extends StatelessWidget {
  final AppNotification notif;
  final Future<void> Function(AppNotification) onTap;

  const _NotificationCard({required this.notif, required this.onTap});

  // Map known payload types to a representative icon + tint. Used as the
  // fallback visual when the notification's payload doesn't include an image.
  ({IconData icon, Color color}) _iconFor(ThemeData theme) {
    switch (notif.payloadType) {
      case 'news_posted':
      case 'news_published':
        return (icon: Icons.article_outlined, color: theme.appPrimary);
      case 'comment_reply':
        return (icon: Icons.reply_rounded, color: const Color(0xFF8B5CF6));
      case 'comment_new':
        return (
          icon: Icons.mode_comment_outlined,
          color: const Color(0xFF0EA5E9),
        );
      default:
        return (
          icon: Icons.notifications_none_rounded,
          color: theme.appTextSecondary,
        );
    }
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${t.day}/${t.month}/${t.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconInfo = _iconFor(theme);
    final unread = !notif.isRead;
    final title = notif.title ?? 'Notification';
    final body = notif.body ?? '';
    final imageUrl = notif.image;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Material(
      // Unread sits on the primary (blue) tint, read on a warm orange one, so
      // the two states stay distinguishable by hue and not just by weight.
      color: unread
          ? theme.appPrimary.withValues(alpha: 0.12)
          : _kReadTint.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onTap(notif),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: unread
                  ? theme.appPrimary.withValues(alpha: 0.25)
                  : _kReadTint.withValues(alpha: 0.22),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show the news image when the payload carries one — falls back
              // to the type-based icon tile when missing (e.g. older
              // notifications saved before `image` was added to the payload).
              if (hasImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: CachedImageWidget(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: Container(
                        color: iconInfo.color.withValues(alpha: 0.12),
                      ),
                      errorWidget: Container(
                        color: iconInfo.color.withValues(alpha: 0.12),
                        child: Icon(
                          iconInfo.icon,
                          color: iconInfo.color,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconInfo.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(iconInfo.icon, color: iconInfo.color, size: 20),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: scaledFontSize(14),
                              // Bold while unread, lighter once opened — the
                              // main at-a-glance cue for what's already seen.
                              fontWeight:
                                  unread ? FontWeight.w700 : FontWeight.w500,
                              color: unread
                                  ? theme.appTextPrimary
                                  : theme.appTextSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: theme.appPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        body,
                        style: TextStyle(
                          fontSize: scaledFontSize(12),
                          color: theme.appTextSecondary,
                          height: 1.35,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _relativeTime(notif.createdAt),
                      style: TextStyle(
                        fontSize: scaledFontSize(11),
                        color: theme.appTextLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
