import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../models/app_notification.dart';

/// Target audience for an admin broadcast.
enum NotificationTarget { all, users, guests }

extension NotificationTargetX on NotificationTarget {
  String get value {
    switch (this) {
      case NotificationTarget.all:
        return 'all';
      case NotificationTarget.users:
        return 'users';
      case NotificationTarget.guests:
        return 'guests';
    }
  }
}

abstract class NotificationRepository {
  Future<bool> registerGuestToken({
    required String deviceId,
    required String fcmToken,
    int? stateId,
    int? districtId,
    int? mandalId,
  });

  Future<bool> saveUserToken({required String fcmToken});

  /// POST /api/send-notification
  ///
  /// [stateIds] / [districtIds] / [mandalIds] are the news article's locations
  /// and are sent as **top-level** arrays because they are audience filters,
  /// not payload. Backend must narrow the device query to devices registered
  /// in those locations; until it does, every device still receives the push.
  Future<NotificationDispatchResult?> sendNotification({
    required String title,
    required String body,
    NotificationTarget target = NotificationTarget.all,
    List<int>? userIds,
    List<int>? stateIds,
    List<int>? districtIds,
    List<int>? mandalIds,
    Map<String, String>? data,
  });

  /// GET /api/notifications — paginated in-app inbox for the logged-in user.
  /// Returns an empty list on error so callers can render an empty state.
  Future<List<AppNotification>> getNotifications();

  /// GET /api/notifications/unread-count — badge counter for the bell icon.
  Future<int> getUnreadCount();

  /// POST /api/notifications/{id}/mark-as-read
  Future<bool> markAsRead(String notificationId);

  /// POST /api/notifications/mark-all-as-read
  Future<bool> markAllAsRead();
}

class NotificationRepositoryImpl implements NotificationRepository {
  final ApiService _apiService;

  NotificationRepositoryImpl({ApiService? apiService})
    : _apiService = apiService ?? ApiService.instance;

  @override
  Future<bool> registerGuestToken({
    required String deviceId,
    required String fcmToken,
    int? stateId,
    int? districtId,
    int? mandalId,
  }) async {
    try {
      final body = {
        'device_id': deviceId,
        'fcm_token': fcmToken,
        if (stateId != null) 'state_id': stateId,
        if (districtId != null) 'district_id': districtId,
        if (mandalId != null) 'mandal_id': mandalId,
      };
      debugPrint(
        '[NotificationRepository] POST ${AppConstants.guestFcmToken} '
        'body=$body',
      );

      final response = await _apiService.post(
        AppConstants.guestFcmToken,
        body: body,
        showErrorAlert: false,
      );

      debugPrint(
        '[NotificationRepository] POST ${AppConstants.guestFcmToken} '
        'response=$response',
      );

      if (response.containsKey('error')) {
        debugPrint(
          '[NotificationRepository] registerGuestToken FAILED — '
          'status=${response['statusCode']} '
          'message=${response['message']} '
          'error=${response['error']}',
        );
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('[NotificationRepository] registerGuestToken exception: $e');
      return false;
    }
  }

  @override
  Future<bool> saveUserToken({required String fcmToken}) async {
    try {
      final response = await _apiService.post(
        AppConstants.userFcmToken,
        body: {'fcm_token': fcmToken},
        useAuth: true,
        showErrorAlert: false,
      );

      if (response.containsKey('error')) {
        debugPrint(
          '[NotificationRepository] saveUserToken failed: '
          '${response['error']}',
        );
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('[NotificationRepository] saveUserToken exception: $e');
      return false;
    }
  }

  @override
  Future<NotificationDispatchResult?> sendNotification({
    required String title,
    required String body,
    NotificationTarget target = NotificationTarget.all,
    List<int>? userIds,
    List<int>? stateIds,
    List<int>? districtIds,
    List<int>? mandalIds,
    Map<String, String>? data,
  }) async {
    try {
      final requestBody = <String, dynamic>{
        'title': title,
        'body': body,
        'target': target.value,
        if (userIds != null && userIds.isNotEmpty) 'user_ids': userIds,
        if (stateIds != null && stateIds.isNotEmpty) 'state_ids': stateIds,
        if (districtIds != null && districtIds.isNotEmpty)
          'district_ids': districtIds,
        if (mandalIds != null && mandalIds.isNotEmpty) 'mandal_ids': mandalIds,
        if (data != null && data.isNotEmpty) 'data': data,
      };
      debugPrint(
        '[NotificationRepository] POST ${AppConstants.sendNotification} '
        'body=$requestBody',
      );
      final response = await _apiService.post(
        AppConstants.sendNotification,
        body: requestBody,
        useAuth: true,
        showErrorAlert: false,
      );

      if (response.containsKey('error')) {
        return null;
      }

      final summary = response['summary'];
      if (summary is Map<String, dynamic>) {
        return NotificationDispatchResult.fromJson(summary);
      }
      return const NotificationDispatchResult(successCount: 0, failureCount: 0);
    } catch (e) {
      debugPrint('[NotificationRepository] sendNotification exception: $e');
      return null;
    }
  }

  @override
  Future<List<AppNotification>> getNotifications() async {
    try {
      final response = await _apiService.get(
        AppConstants.notifications,
        useAuth: true,
        showErrorAlert: false,
      );

      // Laravel paginate ships the rows under a `data` key alongside meta.
      final rows = response['data'];
      if (rows is List) {
        return rows
            .whereType<Map<String, dynamic>>()
            .map(AppNotification.fromJson)
            .toList();
      }

      if (response.containsKey('error')) {
        debugPrint(
          '[NotificationRepository] getNotifications failed: '
          '${response['error']}',
        );
      }
      return const <AppNotification>[];
    } catch (e) {
      debugPrint('[NotificationRepository] getNotifications exception: $e');
      return const <AppNotification>[];
    }
  }

  @override
  Future<int> getUnreadCount() async {
    try {
      final response = await _apiService.get(
        AppConstants.notificationsUnreadCount,
        useAuth: true,
        showErrorAlert: false,
      );
      final count = response['unread_count'];
      if (count is num) return count.toInt();
      return 0;
    } catch (e) {
      debugPrint('[NotificationRepository] getUnreadCount exception: $e');
      return 0;
    }
  }

  @override
  Future<bool> markAsRead(String notificationId) async {
    try {
      final response = await _apiService.post(
        '${AppConstants.notifications}/$notificationId/mark-as-read',
        body: const {},
        useAuth: true,
        showErrorAlert: false,
      );
      return !response.containsKey('error');
    } catch (e) {
      debugPrint('[NotificationRepository] markAsRead exception: $e');
      return false;
    }
  }

  @override
  Future<bool> markAllAsRead() async {
    try {
      final response = await _apiService.post(
        AppConstants.notificationsMarkAllRead,
        body: const {},
        useAuth: true,
        showErrorAlert: false,
      );
      return !response.containsKey('error');
    } catch (e) {
      debugPrint('[NotificationRepository] markAllAsRead exception: $e');
      return false;
    }
  }
}

/// Result returned by `/api/send-notification` summary block.
class NotificationDispatchResult {
  final int successCount;
  final int failureCount;

  const NotificationDispatchResult({
    required this.successCount,
    required this.failureCount,
  });

  factory NotificationDispatchResult.fromJson(Map<String, dynamic> json) {
    return NotificationDispatchResult(
      successCount: (json['success_count'] as num?)?.toInt() ?? 0,
      failureCount: (json['failure_count'] as num?)?.toInt() ?? 0,
    );
  }
}
