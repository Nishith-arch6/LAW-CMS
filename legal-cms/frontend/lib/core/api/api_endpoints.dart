class ApiEndpoints {
  static const String baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '/api');

  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String usersMe = '/users/me';
  static const String usersMePhoto = '/users/me/photo';

  static const String cases = '/cases/';
  static String caseDetail(int id) => '/cases/$id';
  static String caseTimeline(int id) => '/cases/$id/timeline';
  static const String caseDashboard = '/cases/stats/dashboard';

  static const String clients = '/clients/';
  static String clientDetail(int id) => '/clients/$id';
  static String clientCases(int id) => '/clients/$id/cases';

  static const String hearings = '/hearings/';
  static const String hearingsToday = '/hearings/today';
  static const String hearingsWeek = '/hearings/week';
  static String hearingDetail(int id) => '/hearings/$id';

  static const String documents = '/documents/';
  static const String documentsList = '/documents/';
  static String caseDocuments(int caseId) => '/documents/case/$caseId';
  static String documentDownload(int id) => '/documents/$id/download';
  static String documentOcr(int id) => '/documents/$id/ocr-text';

  static const String mlClassify = '/ml/classify';
  static const String mlSuggest = '/ml/suggest-category';
  static const String mlAnalyzeDoc = '/ml/analyze-document';
  static const String mlSearchSimilar = '/ml/search-similar';

  static const String search = '/search/';

  static const String notifications = '/notifications/';
  static const String testReminder = '/notifications/test-reminder';
}
