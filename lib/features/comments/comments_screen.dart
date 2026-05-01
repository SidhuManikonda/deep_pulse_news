import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/news.dart';
import '../../data/models/comment.dart';
import '../../data/repositories/comments_repository.dart';
import '../../providers/app_providers.dart';
import 'comments_view_model.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../shared/widgets/report_bottom_sheet.dart';

class CommentsScreen extends ConsumerStatefulWidget {
  final News news;
  final VoidCallback? onCommentPosted;

  const CommentsScreen({super.key, required this.news, this.onCommentPosted});

  @override
  ConsumerState<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends ConsumerState<CommentsScreen> {
  late CommentsViewModel _viewModel;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final commentsRepository = ref.read(commentsRepositoryProvider);
    _viewModel = CommentsViewModel(
      commentsRepository: commentsRepository,
      news: widget.news,
    );
    _viewModel.commentController.addListener(_onCommentTextChanged);
    _viewModel.replyController.addListener(_onCommentTextChanged);
  }

  @override
  void dispose() {
    _viewModel.commentController.removeListener(_onCommentTextChanged);
    _viewModel.replyController.removeListener(_onCommentTextChanged);
    _viewModel.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _onCommentTextChanged() {
    setState(() {});
  }

  String _currentUserName() {
    return ref.read(authViewModelProvider).user?.name ?? '';
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inSeconds < 60) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
      if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
      return '${(diff.inDays / 365).floor()}y ago';
    } catch (_) {
      return '';
    }
  }

  Color _avatarColor(String name) {
    final colors = [
      Colors.blue,
      Colors.teal,
      Colors.deepPurple,
      Colors.orange,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
      Colors.amber.shade700,
    ];
    final index = name.isEmpty ? 0 : name.codeUnitAt(0) % colors.length;
    return colors[index];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.appTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Comments',
              style: TextStyle(
                fontSize: scaledFontSize(18),
                fontWeight: FontWeight.bold,
                color: theme.appTextPrimary,
              ),
            ),
            ListenableBuilder(
              listenable: _viewModel,
              builder: (context, _) => Text(
                '${_viewModel.comments.length} comments',
                style: TextStyle(
                  fontSize: scaledFontSize(12),
                  color: theme.appTextLight,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: theme.dividerColor),
        ),
      ),
      body: Column(
        children: [
          // Comments list
          Expanded(child: _buildCommentsSection(context, theme)),

          // Reply banner
          ListenableBuilder(
            listenable: _viewModel,
            builder: (context, child) {
              if (_viewModel.replyingToComment != null) {
                return _buildReplyBanner(context, theme);
              }
              return const SizedBox.shrink();
            },
          ),

          // Input bar
          _buildCommentInput(context, theme),
        ],
      ),
    );
  }

  Widget _buildCommentsSection(BuildContext context, ThemeData theme) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        if (_viewModel.isLoading) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: theme.appPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading comments...',
                  style: TextStyle(
                    fontSize: scaledFontSize(14),
                    color: theme.appTextLight,
                  ),
                ),
              ],
            ),
          );
        }

        if (_viewModel.error != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off, size: 48, color: theme.appTextLight),
                const SizedBox(height: 16),
                Text(
                  'Couldn\'t load comments',
                  style: TextStyle(
                    fontSize: scaledFontSize(16),
                    fontWeight: FontWeight.w600,
                    color: theme.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _viewModel.refreshComments(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Try again'),
                ),
              ],
            ),
          );
        }

        if (_viewModel.comments.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: theme.appPrimary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    size: 32,
                    color: theme.appPrimary.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'No comments yet',
                  style: TextStyle(
                    fontSize: scaledFontSize(17),
                    fontWeight: FontWeight.w600,
                    color: theme.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Be the first to share your thoughts!',
                  style: TextStyle(
                    fontSize: scaledFontSize(14),
                    color: theme.appTextLight,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _viewModel.refreshComments,
          color: theme.appPrimary,
          child: ListView.builder(
            controller: _scrollController,
            reverse: true,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            itemCount: _viewModel.comments.length,
            itemBuilder: (context, index) {
              final comment = _viewModel.comments[index];
              return _buildCommentItem(context, theme, comment);
            },
          ),
        );
      },
    );
  }

  Widget _buildCommentItem(
    BuildContext context,
    ThemeData theme,
    Comment comment,
  ) {
    final currentUserName = _currentUserName();
    final isCurrentUser =
        currentUserName.isNotEmpty &&
        comment.userName.toLowerCase() == currentUserName.toLowerCase();
    final avatarColor = _avatarColor(comment.userName);
    final timeAgo = _timeAgo(comment.createdAt);

    const actionColor = Color(0xFF999999);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main comment — always left aligned
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: avatarColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    comment.userName.isNotEmpty
                        ? comment.userName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: scaledFontSize(16),
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Bubble + actions
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bubble
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: isCurrentUser
                            ? const Color(0xFFE7F8E8)
                            : const Color(0xFFF2F2F2),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(2),
                          topRight: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name + district
                          Row(
                            children: [
                              Text(
                                isCurrentUser ? 'You' : comment.userName,
                                style: TextStyle(
                                  fontSize: scaledFontSize(13),
                                  fontWeight: FontWeight.w700,
                                  color: isCurrentUser
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFF222222),
                                ),
                              ),
                              if (!isCurrentUser &&
                                  comment.districtName != null &&
                                  comment.districtName!.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.location_on,
                                  size: 11,
                                  color: actionColor,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  comment.districtName!,
                                  style: TextStyle(
                                    fontSize: scaledFontSize(11),
                                    color: actionColor,
                                  ),
                                ),
                              ],
                              // if (isCurrentUser) ...[
                              const Spacer(),
                              Text(
                                timeAgo,
                                style: TextStyle(
                                  fontSize: scaledFontSize(10),
                                  color: actionColor,
                                ),
                              ),
                              // ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Message
                          Text(
                            comment.comment,
                            style: TextStyle(
                              fontSize: scaledFontSize(14),
                              color: const Color(0xFF303030),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Actions row
                    Row(
                      children: [
                        // if (!isCurrentUser)
                        //   Text(
                        //     timeAgo,
                        //     style: TextStyle(
                        //       fontSize: scaledFontSize(11),
                        //       color: actionColor,
                        //     ),
                        //   ),
                        // if (!isCurrentUser) _dot(),
                        // Reply
                        if (!isCurrentUser)
                          GestureDetector(
                            onTap: () {
                              _viewModel.setReplyingTo(comment);
                              _inputFocusNode.requestFocus();
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.reply, size: 15, color: actionColor),
                                const SizedBox(width: 3),
                                Text(
                                  'Reply',
                                  style: TextStyle(
                                    fontSize: scaledFontSize(11),
                                    color: actionColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (!isCurrentUser) _dot(),
                        // Report
                        if (!isCurrentUser)
                          GestureDetector(
                            onTap: () => _showCommentOptions(
                              context,
                              theme,
                              comment,
                              isCurrentUser,
                            ),
                            child: Icon(
                              Icons.flag_outlined,
                              size: 14,
                              color: actionColor,
                            ),
                          ),
                        // Delete (own comment only)
                        if (isCurrentUser) ...[
                          if (!isCurrentUser) _dot(),
                          GestureDetector(
                            onTap: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  title: const Text('Delete comment?'),
                                  content: const Text('This cannot be undone.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await _viewModel.deleteComment(comment.id);
                              }
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: 14,
                                  color: Colors.red.shade300,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Delete',
                                  style: TextStyle(
                                    fontSize: scaledFontSize(11),
                                    color: Colors.red.shade300,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Spacer(),
                        // Like
                        GestureDetector(
                          onTap: () => _viewModel.likeComment(comment),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                comment.isLikedByUser == true
                                    ? Icons.thumb_up
                                    : Icons.thumb_up_outlined,
                                size: 16,
                                color: comment.isLikedByUser == true
                                    ? theme.appPrimary
                                    : actionColor,
                              ),
                              if (comment.likesCount > 0) ...[
                                const SizedBox(width: 3),
                                Text(
                                  '${comment.likesCount}',
                                  style: TextStyle(
                                    fontSize: scaledFontSize(11),
                                    color: actionColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),
                        // Dislike
                        GestureDetector(
                          onTap: () => _viewModel.dislikeComment(comment),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                comment.isLikedByUser == false
                                    ? Icons.thumb_down
                                    : Icons.thumb_down_outlined,
                                size: 18,
                                color: comment.isLikedByUser == false
                                    ? Colors.orange
                                    : actionColor,
                              ),
                              if (comment.dislikesCount > 0) ...[
                                const SizedBox(width: 3),
                                Text(
                                  '${comment.dislikesCount}',
                                  style: TextStyle(
                                    fontSize: scaledFontSize(11),
                                    color: actionColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Replies
          if (comment.replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 4),
              child: Stack(
                children: [
                  // Connector line
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 10,
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      children: comment.replies
                          .map(
                            (reply) => _buildReplyItem(
                              context,
                              theme,
                              reply,
                              parentName: comment.userName,
                              parentText: comment.comment,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReplyItem(
    BuildContext context,
    ThemeData theme,
    Comment reply, {
    String? parentName,
    String? parentText,
  }) {
    final currentUserName = _currentUserName();
    final isCurrentUser =
        currentUserName.isNotEmpty &&
        reply.userName.toLowerCase() == currentUserName.toLowerCase();
    final avatarColor = _avatarColor(reply.userName);
    final timeAgo = _timeAgo(reply.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Small avatar
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: avatarColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                reply.userName.isNotEmpty
                    ? reply.userName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: scaledFontSize(12),
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  decoration: BoxDecoration(
                    color: isCurrentUser
                        ? const Color(0xFFE7F8E8)
                        : const Color(0xFFF2F2F2),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(2),
                      topRight: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  isCurrentUser ? 'You' : reply.userName,
                                  style: TextStyle(
                                    fontSize: scaledFontSize(12),
                                    fontWeight: FontWeight.w700,
                                    color: isCurrentUser
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFF222222),
                                  ),
                                ),
                                Icon(
                                  Icons.location_on,
                                  size: 11,
                                  color: Color(0xFF999999),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  reply.districtName ?? '',
                                  style: TextStyle(
                                    fontSize: scaledFontSize(11),
                                    color: Color(0xFF999999),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              timeAgo,
                              style: TextStyle(
                                fontSize: scaledFontSize(10),
                                color: const Color(0xFF999999),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        reply.comment,
                        style: TextStyle(
                          fontSize: scaledFontSize(13),
                          color: const Color(0xFF303030),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Time + like + dislike
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _viewModel.likeComment(reply),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            reply.isLikedByUser == true
                                ? Icons.thumb_up
                                : Icons.thumb_up_outlined,
                            size: 16,
                            color: reply.isLikedByUser == true
                                ? theme.appPrimary
                                : const Color(0xFF999999),
                          ),
                          if (reply.likesCount > 0) ...[
                            const SizedBox(width: 3),
                            Text(
                              '${reply.likesCount}',
                              style: TextStyle(
                                fontSize: scaledFontSize(10),
                                color: const Color(0xFF999999),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('·', style: TextStyle(color: Color(0xFF999999))),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _viewModel.dislikeComment(reply),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            reply.isLikedByUser == false
                                ? Icons.thumb_down
                                : Icons.thumb_down_outlined,
                            size: 16,
                            color: reply.isLikedByUser == false
                                ? Colors.orange
                                : const Color(0xFF999999),
                          ),
                          if (reply.dislikesCount > 0) ...[
                            const SizedBox(width: 3),
                            Text(
                              '${reply.dislikesCount}',
                              style: TextStyle(
                                fontSize: scaledFontSize(10),
                                color: const Color(0xFF999999),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('·', style: TextStyle(color: Color(0xFF999999))),
                    // const SizedBox(width: 6),
                    // // GestureDetector(
                    // //   onTap: () => _viewModel.dislikeComment(reply),
                    // //   child: Row(
                    // //     mainAxisSize: MainAxisSize.min,
                    // //     children: [
                    // //       Icon(
                    // //         reply.isLikedByUser == false
                    // //             ? Icons.thumb_down
                    // //             : Icons.thumb_down_outlined,
                    // //         size: 16,
                    // //         color: reply.isLikedByUser == false
                    // //             ? Colors.orange
                    // //             : const Color(0xFF999999),
                    // //       ),
                         
                    // //     ],
                    // //   ),
                    // // ),
                
                    // Delete for own replies
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      const Text(
                        '·',
                        style: TextStyle(color: Color(0xFF999999)),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              title: const Text('Delete reply?'),
                              content: const Text('This cannot be undone.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await _viewModel.deleteComment(reply.id);
                          }
                        },
                        child: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: Colors.red.shade300,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 6),
    child: Text(
      '·',
      style: TextStyle(color: Color(0xFF999999), fontWeight: FontWeight.bold),
    ),
  );

  Widget _buildReplyBanner(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.appPrimary.withOpacity(0.05),
        border: Border(
          top: BorderSide(color: theme.appPrimary.withOpacity(0.15)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 24,
            decoration: BoxDecoration(
              color: theme.appPrimary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.reply, size: 16, color: theme.appPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Replying to ${_viewModel.replyingToComment!.userName}',
              style: TextStyle(
                fontSize: scaledFontSize(13),
                color: theme.appPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _viewModel.setReplyingTo(null),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.appPrimary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, size: 14, color: theme.appPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput(BuildContext context, ThemeData theme) {
    final isReplying = _viewModel.replyingToComment != null;
    final controller = isReplying
        ? _viewModel.replyController
        : _viewModel.commentController;
    final isPosting = isReplying ? _viewModel.isReplying : _viewModel.isPosting;
    final hasText = controller.text.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar of current user
          Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: theme.appPrimary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _currentUserName().isNotEmpty
                    ? _currentUserName()[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: scaledFontSize(14),
                  fontWeight: FontWeight.bold,
                  color: theme.appPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Input field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: controller,
                focusNode: _inputFocusNode,
                decoration: InputDecoration(
                  hintText: isReplying
                      ? 'Write a reply...'
                      : 'Write a comment...',
                  hintStyle: TextStyle(
                    color: theme.appTextLight,
                    fontSize: scaledFontSize(14),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
                maxLines: null,
                textInputAction: TextInputAction.newline,
                style: TextStyle(
                  fontSize: scaledFontSize(14),
                  color: theme.appTextPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Send button
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: GestureDetector(
              onTap: (isPosting || !hasText)
                  ? null
                  : () async {
                      setState(() {});
                      final success = isReplying
                          ? await _viewModel.postReply()
                          : await _viewModel.postComment();
                      if (success && widget.onCommentPosted != null) {
                        widget.onCommentPosted!();
                      }
                    },
              child: AnimatedContainer(
                duration:  Duration(milliseconds: 200),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: hasText && !isPosting
                      ? theme.appPrimary
                      : theme.appTextLight.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isPosting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: hasText ? Colors.white : theme.appTextLight,
                          ),
                        )
                      : Icon(
                          Icons.send_rounded,
                          size: 18,
                          color: hasText ? Colors.white : theme.appTextLight,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCommentOptions(
    BuildContext context,
    ThemeData theme,
    Comment comment,
    bool isCurrentUser,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              if (isCurrentUser)
                _OptionTile(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDeleteComment(context, theme, comment);
                  },
                ),
              _OptionTile(
                icon: Icons.flag_outlined,
                label: 'Report',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(ctx);
                  ReportBottomSheet.show(
                    context,
                    type: 'comment',
                    itemId: comment.id,
                  );
                },
              ),
              if (!isCurrentUser)
                _OptionTile(
                  icon: Icons.block,
                  label: 'Block this comment',
                  color: Colors.red,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text('Block Comment'),
                        content: const Text(
                          'Are you sure you want to block this comment? You will no longer see it.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx, true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Block'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    final success = await CommentsRepositoryImpl().blockComment(
                      commentId: comment.id,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? 'Comment blocked'
                                : 'Failed to block comment',
                          ),
                          backgroundColor: success
                              ? Colors.green[600]
                              : Colors.red[600],
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                      if (success) {
                        _viewModel.loadComments();
                      }
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteComment(
    BuildContext context,
    ThemeData theme,
    Comment comment,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Comment'),
        content: const Text(
          'Are you sure you want to delete this comment? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: theme.appTextSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await _viewModel.deleteComment(comment.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Comment deleted' : 'Failed to delete comment',
                    ),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(
          fontSize: scaledFontSize(15),
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      onTap: onTap,
    );
  }
}
