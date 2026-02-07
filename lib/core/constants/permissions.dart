/// Permission constants based on actual API permission slugs
/// These match the permission slugs returned from the backend API
class Permissions {
  // Content Management - Based on actual API response
  static const String createNews = 'create-news';
  static const String editNews = 'edit-news';
  static const String publishNews = 'publish-news';
  static const String deleteNews = 'delete-news';
  static const String viewNews = 'view-news';
  static const String shareNews = 'share-news';
  static const String likeNews = 'like-news';
  static const String uploadMedia = 'upload-media';

  // Comment Management
  static const String commentNews = 'comment-news';
  static const String approveComments = 'approve-comments';
  static const String likeComments = 'like-comments';

  // User Management
  static const String manageUsers = 'manage-users';

  // Topic and Role Management
  static const String manageTopics = 'manage-topics';
  static const String manageRoles = 'manage-roles';
  static const String managePermissions = 'manage-permissions';

  // Settings Management
  static const String manageSettings = 'manage-settings';

  // Legacy constants for backward compatibility
  static const String uploadContent = 'create-news'; // Maps to create-news
  static const String moderateContent = 'edit-news'; // Maps to edit-news
  static const String approveContent = 'publish-news'; // Maps to publish-news
  static const String deleteContent = 'delete-news'; // Maps to delete-news

  // Content Categories - Role-based content access
  static const String accessYourArea = 'access_your_area';
  static const String accessState = 'access_state';
  static const String accessNational = 'access_national';
  static const String accessInternational = 'access_international';
  static const String accessCinema = 'access_cinema';
  static const String accessGames = 'access_games';
  static const String accessSpecial = 'access_special';
  static const String accessMobiles = 'access_mobiles';
  static const String accessEducation = 'access_education';
  static const String accessCalendar = 'access_calendar';
  static const String accessMyJourney = 'access_my_journey';
  static const String accessPoster = 'access_poster';
  static const String accessStatus = 'access_status';
  static const String accessQuiz = 'access_quiz';
  static const String accessWeeklyAds = 'access_weekly_ads';
  static const String accessJobs = 'access_jobs';
}
