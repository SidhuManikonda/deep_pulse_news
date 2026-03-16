class AppConstants {
  static const String appName = 'NewsApp';
  static const String baseUrl = 'https://deeppulse.co.in/newapp-api/api';
  static const String imageBaseUrl = 'https://deeppulse.co.in';
  static const String appVersion = '1.0.5';
  // API Endpoints
  static const String register = '/register';
  static const String login = '/login';
  static const String languages = '/news-languages';
  static const String user = '/user';
  static const String userList = '/user/list';
  static const String topics = '/topics';
  static const String states = '/states';
  static const String districts = '/districts';
  static const String mandals = '/mandals';
  static const String news = '/news';
  static const String newsStatus = '/news-status';
  static const String comments = '/comments';
  static const String likeDislike = '/likeDislike';
  static const String commentsReply = '/comments/reply';

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
