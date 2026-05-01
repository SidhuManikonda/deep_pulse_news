import 'package:flutter/material.dart';
import '../../data/models/comment.dart';
import '../../data/models/likeable_type.dart';
import '../../data/models/news.dart';
import '../../data/repositories/comments_repository.dart';

class CommentsViewModel extends ChangeNotifier {
  final CommentsRepository _commentsRepository;
  final News _news;

  List<Comment> _comments = [];
  bool _isLoading = false;
  bool _isPosting = false;
  bool _isReplying = false;
  String? _error;
  final TextEditingController commentController = TextEditingController();
  final TextEditingController replyController = TextEditingController();
  Comment? _replyingToComment;

  CommentsViewModel({
    required CommentsRepository commentsRepository,
    required News news,
  }) : _commentsRepository = commentsRepository,
       _news = news {
    loadComments();
  }

  // Getters
  List<Comment> get comments => _comments;
  bool get isLoading => _isLoading;
  bool get isPosting => _isPosting;
  bool get isReplying => _isReplying;
  String? get error => _error;
  News get news => _news;
  Comment? get replyingToComment => _replyingToComment;

  // Load comments for the news.
  // When silent=true, existing list stays visible (no spinner) — used after posting.
  Future<void> loadComments({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      _comments = await _commentsRepository.getComments(newsId: _news.id);
    } catch (e) {
      if (!silent) _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Post a new comment
  Future<bool> postComment() async {
    final content = commentController.text.trim();
    if (content.isEmpty) return false;

    _isPosting = true;
    _error = null;
    notifyListeners();

    try {
      final newComment = await _commentsRepository.postComment(
        content: content,
        newsId: _news.id,
      );

      if (newComment != null) {
        _comments.insert(0, newComment);
        commentController.clear();
        notifyListeners();
        // Silent background sync to get server-assigned IDs without showing a spinner.
        loadComments(silent: true);
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isPosting = false;
      notifyListeners();
    }
  }

  // Refresh comments
  Future<void> refreshComments() async {
    await loadComments();
  }

  // Like a comment
  Future<void> likeComment(Comment comment) async {
    final wasLiked = comment.isLikedByUser == true;
    // Toggle: if already liked, remove like; otherwise like
    if (wasLiked) {
      comment.likesCount--;
      comment.isLikedByUser = null;
    } else {
      if (comment.isLikedByUser == false) {
        comment.dislikesCount--;
      }
      comment.likesCount++;
      comment.isLikedByUser = true;
    }
    notifyListeners();

    try {
      await _commentsRepository.likeDislike(
        likeableId: comment.id,
        likeableType: LikeableType.comment,
        isLike: true,
      );
    } catch (_) {
      await loadComments(silent: true);
    }
  }

  // Dislike a comment
  Future<void> dislikeComment(Comment comment) async {
    final wasDisliked = comment.isLikedByUser == false;
    if (wasDisliked) {
      comment.dislikesCount--;
      comment.isLikedByUser = null;
    } else {
      if (comment.isLikedByUser == true) {
        comment.likesCount--;
      }
      comment.dislikesCount++;
      comment.isLikedByUser = false;
    }
    notifyListeners();

    try {
      await _commentsRepository.likeDislike(
        likeableId: comment.id,
        likeableType: LikeableType.comment,
        isLike: false,
      );
    } catch (_) {
      await loadComments(silent: true);
    }
  }

  // Delete a comment
  Future<bool> deleteComment(int commentId) async {
    try {
      final success = await _commentsRepository.deleteComment(commentId: commentId);
      if (success) {
        _comments.removeWhere((c) => c.id == commentId);
        // Also remove from replies
        for (final comment in _comments) {
          comment.replies.removeWhere((r) => r.id == commentId);
        }
        notifyListeners();
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  // Set comment to reply to
  void setReplyingTo(Comment? comment) {
    _replyingToComment = comment;
    if (comment == null) {
      replyController.clear();
    }
    notifyListeners();
  }

  // Post a reply to a comment
  Future<bool> postReply() async {
    final content = replyController.text.trim();
    if (content.isEmpty || _replyingToComment == null) return false;

    _isReplying = true;
    _error = null;
    notifyListeners();

    try {
      final newReply = await _commentsRepository.replyComment(
        newsId: _news.id,
        parentId: _replyingToComment!.id,
        comment: content,
      );

      if (newReply != null) {
        final parentIndex = _comments.indexWhere((comment) => comment.id == _replyingToComment!.id);
        if (parentIndex != -1) {
          _comments[parentIndex].replies.insert(0, newReply);
        }
        replyController.clear();
        _replyingToComment = null;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isReplying = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    commentController.dispose();
    replyController.dispose();
    super.dispose();
  }
}
