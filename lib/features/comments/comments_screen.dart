import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/news.dart';
import '../../data/models/comment.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/auto_scaled_text.dart';
import 'comments_view_model.dart';

class CommentsScreen extends ConsumerStatefulWidget {
  final News news;
  final VoidCallback? onCommentPosted; // Callback to refresh news data

  const CommentsScreen({super.key, required this.news, this.onCommentPosted});

  @override
  ConsumerState<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends ConsumerState<CommentsScreen> {
  late CommentsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    final commentsRepository = ref.read(commentsRepositoryProvider);
    _viewModel = CommentsViewModel(
      commentsRepository: commentsRepository,
      news: widget.news,
    );

    // Add listener to comment controller for immediate UI updates
    _viewModel.commentController.addListener(_onCommentTextChanged);
    _viewModel.replyController.addListener(_onCommentTextChanged);
  }

  @override
  void dispose() {
    // Remove listener before disposing
    _viewModel.commentController.removeListener(_onCommentTextChanged);
    _viewModel.replyController.removeListener(_onCommentTextChanged);
    _viewModel.dispose();
    super.dispose();
  }

  // Callback for text changes to trigger UI updates
  void _onCommentTextChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.news.getPrimaryTranslation()?.title ?? 'No title',
          style: TextStyle(
            // fontSize: fontSize * 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          // News preview section
          // _buildNewsPreview(context, ref),

          // Comments section
          Expanded(child: _buildCommentsSection(context)),

          // Reply banner (if replying to a comment)
          ListenableBuilder(
            listenable: _viewModel,
            builder: (context, child) {
              if (_viewModel.replyingToComment != null) {
                return _buildReplyBanner(context);
              }
              return const SizedBox.shrink();
            },
          ),

          // Comment input section
          _buildCommentInput(context),
        ],
      ),
    );
  }

  Widget _buildCommentsSection(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        if (_viewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_viewModel.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                AutoScaledText(
                  'Failed to load comments',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _viewModel.refreshComments(),
                  child: const AutoScaledText('Retry'),
                ),
              ],
            ),
          );
        }

        if (_viewModel.comments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.comment_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                AutoScaledText(
                  'No comments yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                AutoScaledText(
                  'Be the first to comment!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _viewModel.refreshComments,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _viewModel.comments.length,
            itemBuilder: (context, index) {
              final comment = _viewModel.comments[index];
              return _buildCommentItem(context, comment);
            },
          ),
        );
      },
    );
  }

  Widget _buildCommentItem(BuildContext context, Comment comment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.2),
                    child: Icon(
                      Icons.person,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AutoScaledText(
                    comment.userName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AutoScaledText(
                comment.comment,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  _viewModel.setReplyingTo(comment);
                },
                child: Row(
                  children: [
                    Icon(
                      Icons.reply,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    AutoScaledText(
                      'Reply',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Display replies if any exist
        if (comment.replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: comment.replies
                  .map((reply) => _buildReplyItem(context, reply))
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildReplyItem(BuildContext context, Comment reply) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.secondary.withOpacity(0.2),
                child: Icon(
                  Icons.person,
                  size: 14,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 6),
              AutoScaledText(
                reply.userName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AutoScaledText(
            reply.comment,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.reply,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AutoScaledText(
              'Replying to ${_viewModel.replyingToComment!.userName}',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: () {
              _viewModel.setReplyingTo(null);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput(BuildContext context) {
    final isReplying = _viewModel.replyingToComment != null;
    final controller = isReplying
        ? _viewModel.replyController
        : _viewModel.commentController;
    final isPosting = isReplying ? _viewModel.isReplying : _viewModel.isPosting;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        40,
      ), // Reduced top padding from 16 to 8
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: isReplying
                    ? 'Write a reply...'
                    : 'Write a comment...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.newline,
              onSubmitted: (_) => isReplying
                  ? _viewModel.postReply()
                  : _viewModel.postComment(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: (isPosting || controller.text.trim().isEmpty)
                ? null
                : () async {
                    // Immediate feedback - disable button instantly
                    setState(() {});
                    final success = isReplying
                        ? await _viewModel.postReply()
                        : await _viewModel.postComment();
                    if (success && widget.onCommentPosted != null) {
                      widget.onCommentPosted!(); // Refresh news data
                    }
                  },
            icon: isPosting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.send,
                    color: controller.text.trim().isEmpty
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.primary,
                  ),
          ),
        ],
      ),
    );
  }
}
