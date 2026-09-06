class AppConstants {
  static const String appName = 'NewsApp';
  static const String baseUrl = 'https://api.deeppulse.media/api';
  static const String imageBaseUrl = 'https://deeppulse.co.in';
  static const String appVersion = '1.0.8';
  // API Endpoints
  static const String register = '/register';
  static const String login = '/login';
  static const String languages = '/news-languages';
  static const String user = '/user';
  static const String userList = '/user/list';
  static const String userRoles = '/user/roles';
  static const String topics = '/topics';
  static const String states = '/states';
  static const String districts = '/districts';
  static const String mandals = '/mandals';
  static const String news = '/news';

  /// Standalone adverts. Authenticated CRUD; the reader feed gets published
  /// ads inline from `/news` instead.
  static const String ads = '/ads';
  static const String newsStatus = '/news-status';
  static const String comments = '/comments';
  static const String commentUsers = '/comment-users';
  static const String likeDislike = '/likeDislike';
  static const String commentsReply = '/comments/reply';
  static const String saveNewsView = '/save-news-view';
  static const String updatePassword = '/update-password';
  static const String report = '/report';
  static const String changePassword = '/change-password';
  static const String blockUser = '/users'; // /users/:id/block — block a user (any authenticated user)
  static const String blockComment = '/comments'; // /comments/:id/block — block a comment
  static const String toggleBlockUser = '/user'; // /user/:id/toggle-block — admin only
  static const String googleLogin = '/googleLogin';
  static const String logout = '/logout';
  static const String deleteAccount = '/user/account';
  static const String updateProfileImage = '/user/profile-image';

  // FCM / Notifications
  static const String guestFcmToken = '/guest/fcm-token';
  static const String userFcmToken = '/fcm-token';
  static const String sendNotification = '/send-notification';

  // In-app notifications (per-user inbox)
  static const String notifications = '/notifications';
  static const String notificationsUnreadCount = '/notifications/unread-count';
  static const String notificationsMarkAllRead = '/notifications/mark-all-as-read';
  // Per-notification: '/notifications/{id}/mark-as-read'

  // Storage Keys
  static const String selectedLanguageKey = 'selected_language';
  static const String selectedTopicsKey = 'selected_topics';
  static const String userTokenKey = 'user_token';
  static const String onboardingCompleteKey = 'onboarding_complete';

  // Default Values
  static const String defaultLanguage = 'en';
  static const int articlesPerPage = 20;
  static const int maxCacheAge = 300; // 5 minutes in seconds
}
