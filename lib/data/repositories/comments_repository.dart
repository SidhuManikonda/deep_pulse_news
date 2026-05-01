import 'package:flutter/foundation.dart';

import '../models/comment.dart';
import '../models/user_comment.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/app_constants.dart';
import '../models/likeable_type.dart';

abstract class CommentsRepository {
  Future<Comment?> postComment({required String content, required int newsId});
  Future<Comment?> replyComment({
    required int newsId,
    required int parentId,
    required String comment,
  });
  Future<List<Comment>> getComments({required int newsId});
  Future<void> likeDislike({
    required int likeableId,
    required LikeableType likeableType,
    required bool isLike,
  });
  Future<List<UserCommentEntry>> getUserComments({required int userId});
  Future<bool> deleteComment({required int commentId});
  Future<bool> blockComment({required int commentId});
}

class CommentsRepositoryImpl implements CommentsRepository {
  final ApiService _apiService;

  CommentsRepositoryImpl({ApiService? apiService})
    : _apiService = apiService ?? ApiService.instance;

  @override
  Future<Comment?> postComment({
    required String content,
    required int newsId,
  }) async {
    try {
      final body = {'content': content, 'news_id': newsId};

      final response = await _apiService.post(
        AppConstants.comments,
        body: body,
        useAuth: true,
      );

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      if (response.containsKey('comment')) {
        final commentJson = response['comment'] as Map<String, dynamic>;
        final comment = Comment.fromJson(commentJson);
        return comment;
      } else if (response.containsKey('data')) {
        return Comment.fromJson(response['data']);
      }

      return null;
    } catch (e) {
      throw Exception('Failed to post comment: $e');
    }
  }

  @override
  Future<Comment?> replyComment({
    required int newsId,
    required int parentId,
    required String comment,
  }) async {
    try {
      final body = {
        'news_id': newsId,
        'parent_id': parentId,
        'comment': comment,
      };

      final response = await _apiService.post(
        AppConstants.commentsReply,
        body: body,
        useAuth: true,
      );

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      if (response.containsKey('comment')) {
        final commentJson = response['comment'] as Map<String, dynamic>;
        final replyComment = Comment.fromJson(commentJson);
        return replyComment;
      } else if (response.containsKey('data')) {
        return Comment.fromJson(response['data']);
      }

      return null;
    } catch (e) {
      throw Exception('Failed to reply to comment: $e');
    }
  }

  @override
  Future<List<Comment>> getComments({required int newsId}) async {
    try {
      final response = await _apiService.get(
        '${AppConstants.comments}/$newsId',
        useAuth: true,
        showErrorAlert: false,
      );

      if (response is List) {
        return response.map((json) => Comment.fromJson(json)).toList();
      }

      if (response is Map<String, dynamic>) {
        if (response['message']?.toString().toLowerCase().contains(
              'no comments',
            ) ==
            true) {
          return [];
        }

        // Handle double-nested paginated response: { data: { data: [...] } }
        if (response.containsKey('data') && response['data'] is Map<String, dynamic>) {
          final paginatedData = response['data'] as Map<String, dynamic>;
          if (paginatedData.containsKey('data') && paginatedData['data'] is List) {
            final comments = paginatedData['data'] as List<dynamic>;
            return comments.map((json) => Comment.fromJson(json)).toList();
          }
        }

        // Handle flat paginated response: { data: [...] }
        if (response.containsKey('data') && response['data'] is List) {
          final comments = response['data'] as List<dynamic>;
          return comments.map((json) => Comment.fromJson(json)).toList();
        }

        if (response.containsKey('comments')) {
          final comments = response['comments'] as List<dynamic>;
          return comments.map((json) => Comment.fromJson(json)).toList();
        }
        if (response.containsKey('error')) {
          throw Exception(response['error']);
        }
      }

      return [];
    } catch (e) {
      throw Exception('Failed to fetch comments: $e');
    }
  }

  @override
  Future<List<UserCommentEntry>> getUserComments({required int userId}) async {
    try {
      final response = await _apiService.get(
        AppConstants.commentUsers,
        queryParameters: {'user_id': userId.toString()},
        useAuth: true,
        showErrorAlert: false,
      );

      final data = response['data'] as List<dynamic>? ?? [];
      return data
          .map((e) => UserCommentEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch user comments: $e');
    }
  }

  @override
  Future<void> likeDislike({
    required int likeableId,
    required LikeableType likeableType,
    required bool isLike,
  }) async {
    try {
      final body = {
        'likeable_id': likeableId,
        'likeable_type': likeableType.value,
        'is_like': isLike ? 1 : 0,
      };

      debugPrint('LIKE/DISLIKE REQUEST: $body');
      final response = await _apiService.post(
        AppConstants.likeDislike,
        body: body,
        useAuth: true,
      );
      debugPrint('LIKE/DISLIKE RESPONSE: $response');

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }
    } catch (e) {
      debugPrint('LIKE/DISLIKE ERROR: $e');
      throw Exception('Failed to like/dislike: $e');
    }
  }

  @override
  Future<bool> deleteComment({required int commentId}) async {
    try {
      final response = await _apiService.delete(
        '${AppConstants.comments}/$commentId',
        useAuth: true,
      );

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> blockComment({required int commentId}) async {
    try {
      final response = await _apiService.post(
        '${AppConstants.blockComment}/$commentId/block',
        body: {},
        useAuth: true,
      );

      if (response.containsKey('error')) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}
