import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/user.dart';
import '../../data/models/user_comment.dart';
import '../../providers/app_providers.dart';

class UserCommentsScreen extends ConsumerStatefulWidget {
  final User user;

  const UserCommentsScreen({super.key, required this.user});

  @override
  ConsumerState<UserCommentsScreen> createState() => _UserCommentsScreenState();
}

class _UserCommentsScreenState extends ConsumerState<UserCommentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(adminUserManagementControllerProvider)
          .fetchUserComments(widget.user.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = ref.watch(adminUserManagementControllerProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(theme),
      body: Column(
        children: [
          _buildUserInfoCard(theme),
          Expanded(child: _buildBody(controller, theme)),
        ],
      ),
    );
  }

  AppBar _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            color: theme.appTextPrimary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'User Comments',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: theme.appTextPrimary,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: theme.appDivider),
      ),
    );
  }

  Widget _buildUserInfoCard(ThemeData theme) {
    final user = widget.user;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.appCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.appGrey200),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: theme.appPrimary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.appPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  user.email,
                  style: TextStyle(
                      fontSize: 13, color: theme.appTextSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  user.mobile,
                  style:
                      TextStyle(fontSize: 13, color: theme.appTextSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: user.isActive
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: user.isActive ? Colors.green : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(dynamic controller, ThemeData theme) {
    if (controller.isLoadingComments) {
      return Center(
        child: CircularProgressIndicator(
          color: theme.appPrimary,
          strokeWidth: 2.5,
        ),
      );
    }

    if (controller.commentsError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              'Failed to load comments',
              style:
                  TextStyle(fontSize: 15, color: theme.appTextSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref
                  .read(adminUserManagementControllerProvider)
                  .fetchUserComments(widget.user.id),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.appPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }

    final comments = controller.userComments as List<UserCommentEntry>;

    if (comments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 56, color: theme.appGrey400),
            const SizedBox(height: 12),
            Text(
              'No comments yet',
              style: TextStyle(
                  fontSize: 15,
                  color: theme.appTextSecondary,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: theme.appPrimary,
      onRefresh: () => ref
          .read(adminUserManagementControllerProvider)
          .fetchUserComments(widget.user.id),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: comments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) =>
            _buildCommentCard(comments[index], theme),
      ),
    );
  }

  Widget _buildCommentCard(UserCommentEntry entry, ThemeData theme) {
    final timeAgo = _timeAgo(entry.comment.createdAt);

    return Container(
      decoration: BoxDecoration(
        color: theme.appCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.appGrey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // News title header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.appGrey50,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: theme.appDivider)),
            ),
            child: Row(
              children: [
                Icon(Icons.article_outlined,
                    size: 15, color: theme.appTextSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    entry.news.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.appTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                _buildStatusChip(entry.news.status, theme),
              ],
            ),
          ),

          // Comment content
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Text(
              entry.comment.content,
              style: TextStyle(
                fontSize: 14,
                color: theme.appTextPrimary,
                height: 1.4,
              ),
            ),
          ),

          // Footer: time + approval badge
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 13, color: theme.appTextLight),
                const SizedBox(width: 4),
                Text(
                  timeAgo,
                  style: TextStyle(fontSize: 12, color: theme.appTextLight),
                ),
                const SizedBox(width: 4),
                Text(
                  '· ${_formatDate(entry.comment.createdAt.toLocal())}',
                  style: TextStyle(fontSize: 11, color: theme.appTextLight),
                ),
                // const Spacer(),
                // _buildApprovalBadge(entry.comment.isApproved, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, ThemeData theme) {
    final isPublished = status == 'published';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isPublished
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isPublished ? Colors.green : Colors.orange,
        ),
      ),
    );
  }

  Widget _buildApprovalBadge(bool isApproved, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isApproved
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isApproved
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isApproved ? Icons.check_circle_rounded : Icons.pending_rounded,
            size: 12,
            color: isApproved ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            isApproved ? 'Approved' : 'Pending',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isApproved ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m $ampm';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
