class AppConfig {

  static const bool isProduction = false;

  static const String devBaseUrl =
      "http://192.168.101.3:8000";

  static const String prodBaseUrl =
      "https://api.seuapp.com";

  static String get baseUrl =>
      isProduction ? prodBaseUrl : devBaseUrl;

  static const int apiTimeoutSeconds = 60;
}