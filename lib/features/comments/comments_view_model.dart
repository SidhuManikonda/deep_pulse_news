import 'package:flutter/material.dart';
import '../../data/models/comment.dart';
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

  // Load comments for the news
  Future<void> loadComments() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _comments = await _commentsRepository.getComments(newsId: _news.id);
      // Removed sorting since createdAt is not available in simplified model
    } catch (e) {
      _error = e.toString();
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
    print('postReply called with content: "$content", replyingTo: ${_replyingToComment?.userName}');
    if (content.isEmpty || _replyingToComment == null) {
      print('postReply: content empty or no replyingToComment');
      return false;
    }

    _isReplying = true;
    _error = null;
    notifyListeners();
    print('postReply: starting API call');

    try {
      final newReply = await _commentsRepository.replyComment(
        newsId: _news.id,
        parentId: _replyingToComment!.id,
        comment: content,
      );
      print('postReply: API call completed, newReply: $newReply');

      if (newReply != null) {
        // Find the parent comment and add the reply to its replies list
        final parentIndex = _comments.indexWhere((comment) => comment.id == _replyingToComment!.id);
        if (parentIndex != -1) {
          _comments[parentIndex].replies.insert(0, newReply);
        }
        replyController.clear();
        _replyingToComment = null;
        notifyListeners();
        print('postReply: success');
        return true;
      }
      print('postReply: API returned null');
      return false;
    } catch (e) {
      print('postReply: error - $e');
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isReplying = false;
      notifyListeners();
      print('postReply: finished');
    }
  }

  @override
  void dispose() {
    commentController.dispose();
    replyController.dispose();
    super.dispose();
  }
}
